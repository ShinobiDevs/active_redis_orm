module ActiveRedis
  module AttributeMethods
    def allow_mass_assignment?(attr)
      self.class.attr_accessible?(attr)
    end

    def set_attributes(attrs)
      if attrs
        attrs.each do |attr, value|
          send("#{attr}=", value) if allow_mass_assignment?(attr) && respond_to?("#{attr}=")
        end
      end
    end

    def update_attributes(attrs)
      set_attributes(attrs)
      save
    end

    def after_set(field_name)
      expire_field(field_name)
    end

    def expire_field(field_name)
      expires_in = self.class.attribute_options[field_name.to_sym][:expires_in]
      if expires_in.to_i > 0
        ActiveRedis.redis.expire(send("#{field_name}_redis_key"), expires_in.to_i)
      end
    end
  end

  module Attributes
    def attr_accessible(*attrs)
      @attr_accessible = attrs
    end

    def attr_accessible?(attr)
      @attr_accessible.nil? || @attr_accessible.include?(attr)
    end

    def define_field(field_name, options)
      define_attribute_methods field_name
      class_eval %Q{
        def #{field_name}_redis_key
          "#{self.redis_namespace}:\#{id}:#{field_name}"
        end

        def refresh_#{field_name}!
          @attributes[:#{field_name}] = nil
          #{field_name}
        end

        def destroy_#{field_name}
          Redis::Value.new(#{field_name}_redis_key).delete
        end
      }
      if options[:finder_field]
        finder_field(field_name, options)
      end
      case options[:type]
      when :set
        set_field(field_name, options)
      when :sorted_set
        sorted_set_field(field_name, options)
      when :list
        list_field(field_name, options)
      when :hash
        hash_field(field_name, options)
      when :float
        float_field(field_name, options)
      when :int, :integer
        integer_field(field_name, options)
      when :counter
        counter_field(field_name, options)
      when :boolean
        boolean_field(field_name, options)
      when :date
        date_field(field_name, options)
      when :time, :datetime, :timestamp
        time_field(field_name, options)
      else
        string_field(field_name, options)
      end
    end

    def string_field(field_name, options)
      class_eval %Q{
        def #{field_name}_object
          Redis::Value.new(#{field_name}_redis_key)
        end

        def #{field_name}
          @attributes[:#{field_name}] ||= begin
            value = #{field_name}_object.value
            value.nil? ? value : value.to_s
          end
        end

        def #{field_name}=(value)
          #{field_name}_will_change!
          @attributes[:#{field_name}] = value
        end

        def set_#{field_name}(value)
          #{field_name}_object.value = value.last
          after_set(:#{field_name})
        end
      }
    end

    def integer_field(field_name, options)
      class_eval %Q{
        def #{field_name}_object
          Redis::Value.new(#{field_name}_redis_key)
        end

        def #{field_name}
          @attributes[:#{field_name}] ||= begin
            value = #{field_name}_object.value
            value.nil? ? value : value.to_i
          end
        end

        def #{field_name}=(value)
          #{field_name}_will_change!
          @attributes[:#{field_name}] = value.to_i
        end

        def set_#{field_name}(value)
          #{field_name}_object.value = value.last.to_i
          after_set(:#{field_name})
        end
      }
    end

    def float_field(field_name, options)
      class_eval %Q{
        def #{field_name}_object
          Redis::Value.new(#{field_name}_redis_key)
        end

        def #{field_name}
          @attributes[:#{field_name}] ||= begin
            value = #{field_name}_object.value
            value.nil? ? value : value.to_f
          end
        end

        def #{field_name}=(value)
          #{field_name}_will_change!
          @attributes[:#{field_name}] = value.to_f
        end

        def set_#{field_name}(value)
          #{field_name}_object.value = value.last.to_f
          after_set(:#{field_name})
        end
      }
    end

    def boolean_field(field_name, options)
      class_eval %Q{
        def #{field_name}_object
          Redis::Value.new(#{field_name}_redis_key)
        end

        def #{field_name}
          return @attributes[:#{field_name}] if @attributes[:#{field_name}].boolean?
          @attributes[:#{field_name}] ||= begin
            value = #{field_name}_object.value
            value = "false" unless value.present?
            value.to_bool
          end
        end

        def #{field_name}?
          !!#{field_name}
        end

        def #{field_name}=(value)
          #{field_name}_will_change!
          if !value.boolean?
            value = value.to_bool
          else
            value = value
          end

          @attributes[:#{field_name}] = value
        end

        def set_#{field_name}(value)
          #{field_name}_object.value = value.last.to_s
          after_set(:#{field_name})
        end
      }
    end

    def counter_field(field_name, options)
      class_eval %Q{
        def #{field_name}_object
          Redis::Counter.new(#{field_name}_redis_key)
        end

        def #{field_name}
          @attributes[:#{field_name}] ||= #{field_name}_object.value.to_i
        end

        def #{field_name}=(#{field_name})
          #{field_name}_will_change!
          @attributes[:#{field_name}] = #{field_name}.to_i
        end

        def set_#{field_name}(value)
          #{field_name}_object.value = value.last.to_i
          after_set(:#{field_name})
        end

        def #{field_name}_inc(count)
          @attributes[:#{field_name}] = #{field_name}_object.increment(count)
        end

        def #{field_name}_dec(count)
          @attributes[:#{field_name}] = #{field_name}_object.decrement(count)
        end
      }
    end

    def list_field(field_name, options)
      class_eval %Q{
        def #{field_name}_object
          Redis::List.new(#{field_name}_redis_key)
        end

        def #{field_name}
          @attributes[:#{field_name}] ||= begin
            ActiveRedis::DirtyObjects::Array.new(#{field_name}_object.values)
          end
        end

        def #{field_name}=(array)
          if !array.is_a?(Array) && array.present?
            array = [array]
          end
          #{field_name}.replace(array) if array.is_a?(Array)

          #{field_name}
        end

        def #{field_name}_force_load
          @attributes[:#{field_name}] = #{field_name}_object.values
        end

        def #{field_name}_count
          #{field_name}_object.count
        end

        def set_#{field_name}(value)
          changes = value.first.last
          changes[:additions].each do |addition|
            #{field_name}_object.push(addition)
          end
          changes[:drops].each do |drop|
            #{field_name}_object.delete(drop)
          end
          after_set(:#{field_name})
        end
      }
    end

    def set_field(field_name, options)
      class_eval %Q{
        def #{field_name}_object
          Redis::Set.new(#{field_name}_redis_key)
        end

        def #{field_name}
          @attributes[:#{field_name}] ||= begin
            ActiveRedis::DirtyObjects::Array.new(#{field_name}_object.members)
          end
        end

        def #{field_name}=(array)
          #{field_name}.replace(array)
        end

        def #{field_name}_count
          #{field_name}_object.count
        end

        def set_#{field_name}(value)
          changes = value.first.last
          changes[:additions].each do |addition|
            #{field_name}_object.add(addition)
          end
          changes[:drops].each do |drop|
            #{field_name}_object.delete(drop)
          end
          after_set(:#{field_name})
        end
      }
    end

    def sorted_set_field(field_name, options)
      class_eval %Q{
        def #{field_name}_object
          Redis::SortedSet.new(#{field_name}_redis_key)
        end

        def #{field_name}
          @attributes[:#{field_name}] ||= begin
            ActiveRedis::DirtyObjects::SortedSet.new(#{field_name}_object.members)
          end
        end

        def #{field_name}_count
          #{field_name}_object.count
        end

        def set_#{field_name}(value)
          changes = value.first.last
          changes[:additions].each do |addition|
            #{field_name}_object[changes[:hash].key(addition)] = addition
          end
          changes[:drops].each do |drop|
            #{field_name}_object.delete(drop)
          end
          after_set(:#{field_name})
        end
      }
    end

    def hash_field(field_name, options)
      class_eval %Q{
        def #{field_name}_hash_set
          Redis::HashKey.new(#{field_name}_redis_key)
        end

        def #{field_name}
          @attributes[:#{field_name}] ||= begin
            ActiveRedis::DirtyObjects::Hash[#{field_name}_hash_set.all]
          end
        end

        def #{field_name}=(value)
          #{field_name}.replace(value)
        end

        def set_#{field_name}(value)
          changes = value.first.last
          changes[:additions].each do |addition|
            #{field_name}_hash_set[addition] = changes[:hash][addition]
          end
          changes[:drops].each do |drop|
            #{field_name}_hash_set.delete(drop)
          end
          after_set(:#{field_name})
        end
      }
    end

    def date_field(field_name, options)
      string_field(field_name, options)
      class_eval %Q{
        def #{field_name}
          @attributes[:#{field_name}] ||= begin
            value = #{field_name}_object.value
            if value.blank?
              nil
            else
              Date.parse(value)
            end
          end
        end

        def set_#{field_name}(value)
          #{field_name}_object.value = value.last.to_s
          after_set(:#{field_name})
        end
      }
    end

    def time_field(field_name, options)
      string_field(field_name, options)
      class_eval %Q{
        def #{field_name}
          @attributes[:#{field_name}] ||= begin
            value = #{field_name}_object.value
            if value.blank?
              nil
            else
              Time.at(value.to_i)
            end
          end
        end

        def set_#{field_name}(value)
          #{field_name}_object.value = value.last.to_i
          after_set(:#{field_name})
        end
      }
    end

    def finder_field(field_name, options)
      before_save do
        if send("#{field_name}_changed?")
          ActiveRedis.redis.del(self.class.finder_key(field_name, send("#{field_name}_was")))
          ActiveRedis.redis.set(self.class.finder_key(field_name, send(field_name)), id)
        end
      end

      class_eval %Q{
        def self.find_by_#{field_name}(value)
          id = Redis.current.get(finder_key("#{field_name}", value))
          if id.present?
            self.find(id)
          else
            nil
          end
        end
      }
    end
  end
end