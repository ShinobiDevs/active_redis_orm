require "active_support/all"
require "redis"
require "active_model"
require "redis-objects"
require "active_redis/base_extensions"
require "active_redis/attributes"
require "active_redis/save"
require "active_redis/dirty_attributes"
require "active_redis/dirty_objects/array"
require "active_redis/dirty_objects/hash"
require "active_redis/dirty_objects/sorted_set"
require "active_redis/all_list"
require "active_redis/timestamps"
require "active_redis/nil_object"

module ActiveRedis
  mattr_accessor :redis
  self.redis ||= Redis.current
  class Base
    include ActiveModel::Model
    extend ActiveModel::Callbacks
    extend ActiveModel::Naming
    include ActiveModel::Serialization
    include ActiveModel::Dirty
    include ActiveModel::Validations

    include ActiveRedis::DirtyAttributes
    include ActiveRedis::Save
    include ActiveRedis::AttributeMethods

    attr_accessor :id
    attr_reader :attributes

    define_model_callbacks :create, :update, :save, :destroy
    include ActiveRedis::AllList

    #initialize with hash
    def initialize(*args)
      @attributes = {}
      if args.first.is_a?(Hash) || args.empty?
        set_attributes(args.first)
        @new_record = true
      elsif args.first.is_a?(String)
        @id = args.first
      end
    end

    def ==(other)
      self.class == other.class && self.id == other.id && id.present?
    end

    def reload!
      @attributes = {}
      self
    end

    def dirty?
      check_for_changes
      self.changes.present?
    end

    def destroy
      run_callbacks :destroy do
        self.class.attributes.each do |attribute|
          send("destroy_#{attribute}")
        end
      end
    end

    class << self
      include ActiveRedis::Attributes
      attr_accessor :attribute_definitions

      def find(id)
        new(id)
      end

      def create(*args)
        object = new(*args)
        object.save
        object
      end

      def field(field_name, options = {})
        self.attribute_definitions ||= {}
        self.attribute_definitions[field_name.to_sym] = options
        define_field(field_name, options)
      end

      def redis_namespace
        self.name.underscore
      end

      def finder_key(field_name, value)
        "#{redis_namespace.pluralize}:#{field_name}_to_#{redis_namespace}_id:#{value}"
      end

      def attributes
        attribute_options.keys
      end

      def attribute_options
        self.attribute_definitions ||= {}
        attribute_definitions
      end

      def inherited(klass)
        class << klass
          self.class_eval do
            define_method :attribute_options do
              self.attribute_definitions.merge(superclass.attribute_options)
            end
          end
        end
      end
    end
  end
end