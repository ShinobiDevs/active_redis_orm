module ActiveRedis
  module AllList
    def self.included(base)
      base.extend(ClassMethods)
      base.after_create :add_to_all_lists
      base.after_destroy :remove_from_all_lists
      class << base
        attr_accessor :all_lists
      end
    end

    def add_to_all_lists
      self.class.all_lists ||= []
      self.class.all_lists.each do |name, options|
        ListWriter.new(self, name, options).add
      end
    end

    def remove_from_all_lists
      self.class.all_lists ||= []
      self.class.all_lists.each do |name, options|
        ListWriter.new(self, name, options).remove
      end
    end

    module ClassMethods
      def list(name, options={})
        self.all_lists ||= {}
        self.all_lists[name.to_sym] ||= options
        class_eval %Q{
          def self.#{name}_ids
            Redis::SortedSet.new(list_key(:#{name}))
          end
        }
      end

      def list_key(name)
        "#{redis_namespace.pluralize}:#{name}"
      end
    end

    class ListWriter
      def initialize(object, name, options = {})
        @object, @name, @options = object, name, options
      end

      def add
        ActiveRedis.redis.zadd(key, Time.now.to_f, @object.id) if should_add?
      end

      def remove
        ActiveRedis.redis.zrem(key, @object.id)
      end

      def key
        @object.class.list_key(@name)
      end

      private

      def should_add?
        if @options[:if].present?
          @options[:if].call(@object)
        else
          true
        end
      end
    end
  end
end