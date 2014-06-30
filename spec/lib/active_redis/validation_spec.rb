require "active_redis_orm"

class ARValidations < ActiveRedis::Base
  field :foo
  field :short

  validates :short, length: { minimum: 5 }
  validates :foo, presence: true

end

describe "ActiveRedis validations" do
  it "isn't valid in case foo and short are't present" do
    foo = ARValidations.new
    foo.should_not be_valid
    foo.errors.messages.keys.should =~ [:short, :foo]
  end

  it "is valid when valid" do
    foo = ARValidations.new(foo: "bla", short: "I am long enough")
    foo.should be_valid
  end

  it "does not save if invalid" do
    foo = ARValidations.new(foo: "bla", short: "abc")
    foo.should_not be_valid
    foo.save.should == false
    foo.should be_new_record
  end

  it "saves when valid" do
    foo = ARValidations.new(foo: "bla", short: "I am long enough")
    foo.save.should == true
    foo.should_not be_new_record
  end

  it "saves when invalid, if we tell it" do
    foo = ARValidations.new(foo: "bla")
    foo.save(validate: false).should == true
    foo.should_not be_new_record
  end
end