module ActiveRedis
  module Timestamps
    def self.included(base)
      base.class_eval do
        field :created_at, type: :time
        field :updated_at, type: :time

        before_save :set_updated_at_to_now
        before_create :set_created_at_to_now
      end
    end

    private

    def set_updated_at_to_now
      self.updated_at = Time.now
    end

    def set_created_at_to_now
      self.created_at = Time.now
    end
  end
end