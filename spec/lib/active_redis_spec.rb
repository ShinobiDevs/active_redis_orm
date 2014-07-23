require "active_redis_orm"

describe ActiveRedis do
  class ActiveRedisObject < ActiveRedis::Base
    attr_accessible :foo, :bar, :list, :set, :sorted_set, :hash, :expired_field, :date, :time

    field :foo, type: :string
    field :bar, finder_field: true
    field :list, type: :list
    field :set, type: :set
    field :sorted_set, type: :sorted_set
    field :hash, type: :hash
    field :expired_field, expires_in: 1
    field :bool, type: :boolean
    field :date, type: :date
    field :time, type: :time

    list :all
    list :all_with_bar, if: lambda{|object| object.bar.present? }

    after_create :afterz_create
    after_update :afterz_update
    after_save :afterz_save

    def afterz_save; end
    def afterz_update; end
    def afterz_create; end
  end

  before do
    ActiveRedis.redis.flushdb
  end

  context "basics" do

    it "has foo defined" do
      ActiveRedisObject.attribute_definitions[:foo].should == {type: :string}
    end

    it "has a redis_namespace" do
      ActiveRedisObject.redis_namespace.should == "active_redis_object"
    end

    it "has the foo getter and setter" do
      ActiveRedisObject.new.should respond_to(:foo)
      ActiveRedisObject.new.should respond_to(:foo=)
      ActiveRedisObject.new.should respond_to(:bar)
    end

    it "gets saved" do
      id = "12341543154342"
      object = ActiveRedisObject.new(id)
      object.foo = "I am foo"
      Redis.current.get("#{ActiveRedisObject.redis_namespace}:#{id}:foo").should be_blank
      object.save
      Redis.current.get("#{ActiveRedisObject.redis_namespace}:#{id}:foo").should == "I am foo"
    end
  end

  context "setters" do
    it "works" do
      object = ActiveRedisObject.create(bar: "wagamama")
      object.foo = "bar"
      object.save
      object.foo.should == "bar"
    end

    it "works for boolean" do
      object = ActiveRedisObject.create(bar: "wagamama")
      object.bool = false
      object.bool.should == false
      object.save
      object.bool.should == false
    end
  end

  context "finder fields" do
    it "can be found by bar" do
      object = ActiveRedisObject.new
      object.bar = "barbar"
      object.save

      ActiveRedisObject.find_by_bar("barbar").should == object
    end

    it "should remove old reference to the object when finder field is changed" do
      object = ActiveRedisObject.create(bar: "barbar")
      object.bar = "baz"
      object.save
      ActiveRedisObject.find_by_bar("barbar").should be_blank
      ActiveRedisObject.find_by_bar("baz").should == object
    end
  end

  context "#dirty?" do
    it "calls #check_for_changes" do
      object = ActiveRedisObject.new
      object.should_receive(:check_for_changes)
      object.dirty?
    end

    it "is not dirty if not changed" do
      object = ActiveRedisObject.new
      object.bar = "barbar"
      object.save
      object.should_not be_dirty
    end

    it "is dirty when changed" do
      object = ActiveRedisObject.new
      object.bar = "barbar"
      object.should be_dirty
    end

    it "is dirty when changing a custom dirty object" do
      object = ActiveRedisObject.new
      object.hash[:foo] = "bar"
      object.should be_dirty
    end
  end

  context "#save" do
    it "only saves dirty attributes" do
      object = ActiveRedisObject.new
      object.bar = "barbar"
      object.save
      object.should_receive(:set_foo).and_call_original
      object.should_not_receive(:set_bar)
      object.foo = "foo"
      object.save
      object.reload!
      object.foo.should == "foo"
      object.bar.should == "barbar"
    end

    it "saves fields like list, set, etc" do
      object = ActiveRedisObject.new
      object.foo = "foo"
      object.list = [1,2,3]
      object.set = [1,2,3]
      object.sorted_set[1] = 1
      object.hash = {foo: :bar}
      object.save
      object.reload!
      object.list.should == ["1","2","3"]
      object.set.should =~ ["1","2","3"]
      object.sorted_set.should == ["1"]
      object.hash.should == {"foo" => "bar"}
    end

    it "saves sorted sets correctly" do
      object = ActiveRedisObject.new
      object.sorted_set["goofy"] = 2
      object.sorted_set["hola"] = 1
      object.save
      object.reload!
      object.sorted_set.should == ["hola", "goofy"]
    end

    it "removes the field if it's set to nil" do
      object = ActiveRedisObject.new
      object.foo = "foo"
      object.save
      object.foo = nil
      object.save
      object.reload!
      object.foo.should == nil
    end

    it "tracks changes well" do
      object = ActiveRedisObject.new
      object.hash = {}
      object.save
      object.hash[:foo] = "1"
      object.save
      object.reload!
      object.hash.should == {"foo" => "1"}
    end

    it "does not keep changes if not saved" do
      object = ActiveRedisObject.new
      object.list = [1,2,3]
      object.save
      object.reload!
      object.list.push("4")
      object.list.should == ["1", "2", "3", "4"]
      object.reload!
      object.list.should == ["1", "2", "3"]
    end
  end

  context "#new_record?" do
    it "is a new record when initialized empty" do
      object = ActiveRedisObject.new
      object.should be_new_record
    end

    it "stops being new record when saved" do
      object = ActiveRedisObject.new
      object.foo = "foo"
      object.save
      object.should_not be_new_record
    end
  end

  context "callbacks" do
    it "calls callbacks on their appropriate times" do
      object = ActiveRedisObject.new(foo: :foo)
      object.should_receive(:afterz_save).twice
      object.should_receive :afterz_create
      object.save
      object.foo = "bar"
      object.should_not_receive :afterz_create
      object.should_receive :afterz_update
      object.save
    end
  end

  context "#destroy" do
    it "removes all data" do
      object = ActiveRedisObject.new(foo: "foo")
      object.save
      object.foo_object.get.should == "foo"

      object.destroy
      object.foo_object.get.should be_nil
    end
  end

  context "field expiry" do
    it "gets expired" do
      object = ActiveRedisObject.create(expired_field: "foo")
      object.expired_field.should == "foo"
      Redis.current.ttl(object.expired_field_redis_key).should > 0
    end
  end

  context "list of items" do
    it "puts the item ids in a list" do
      object = ActiveRedisObject.create(expired_field: "foo")
      ActiveRedisObject.all_ids.members.should == [object.id]
    end

    it "puts the item ids in a list according to the 'if' option" do
      object = ActiveRedisObject.create(bar: "foo")
      non_added = ActiveRedisObject.create(foo: "foo")
      ActiveRedisObject.all_ids.members.should == [object.id, non_added.id]
      ActiveRedisObject.all_with_bar_ids.members.should == [object.id]
    end

    it "removes the item on destroy" do
      object = ActiveRedisObject.create(bar: "foo")
      non_added = ActiveRedisObject.create(foo: "foo")
      object.destroy
      non_added.destroy
      ActiveRedisObject.all_ids.members.should == []
      ActiveRedisObject.all_with_bar_ids.members.should == []
    end
  end

  context "date and time" do
    it "saves date" do
      object = ActiveRedisObject.create(date: Date.today)
      object.date.should == Date.today
      object.reload!
      object.date.should == Date.today
      object.date=Date.yesterday
      object.date.should == Date.yesterday
      object.save
      object.reload!
      object.date.should == Date.yesterday
    end

    it "saves time" do
      #because we're using timestamps, we need to round the time to the nearest second for the comparison to work
      time1 = Time.at(Time.now.to_i)
      time2 = Time.at(10.minutes.ago.to_i)
      object = ActiveRedisObject.create(time: time1)
      object.time.should == time1
      object.reload!
      object.time.should == time1
      object.time=time2
      object.time.should == time2
      object.save
      object.reload!
      object.time.should == time2
    end
  end

  context "inheritence" do
    class InheritedActiveRedis < ActiveRedisObject
      field :inherited_field
    end

    it "should have access to all its attribute definitions" do
      InheritedActiveRedis.attribute_options.keys.should include(:inherited_field)
      InheritedActiveRedis.attribute_options.keys.should include(:foo)
      ActiveRedisObject.attribute_options.keys.should_not include(:inherited_field)
    end
  end

  context "timestamps" do
    class TimestampedRedis < ActiveRedis::Base
      include ActiveRedis::Timestamps

      field :foo
    end

    it "gets timestamped on creation" do
      object = TimestampedRedis.create(foo: "foo")
      (1.second.ago..Time.now).should cover(object.created_at)
      (1.second.ago..Time.now).should cover(object.updated_at)
    end

    it "updated the updated_at field on update, does not change the created_at" do
      created_time = Time.at(12234)
      updated_at = Time.at(1232356)
      Time.stub(:now).and_return(created_time)
      object = TimestampedRedis.create(foo: "foo")
      object.created_at.should == created_time
      Time.stub(:now).and_return(updated_at)
      object.update_attributes(foo: "bar")
      object.updated_at.should == updated_at
      object.created_at.should == created_time
    end
  end

end