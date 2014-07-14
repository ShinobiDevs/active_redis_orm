require "active_redis_orm"

describe ActiveRedis do
  class AttributesObject < ActiveRedis::Base
    attr_accessible :foo, :bar, :list
  end

  it "deals with attributes in string or symbol implementation" do
    AttributesObject.should be_attr_accessible("bar")
    AttributesObject.should be_attr_accessible(:bar)
  end
end