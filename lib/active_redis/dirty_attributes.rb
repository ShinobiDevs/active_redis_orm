module ActiveRedis
  module DirtyAttributes
    def check_for_changes
      @changed_attributes ||= {}
      self.class.attribute_definitions.each do |attribute, options|
        next unless @attributes.key?(attribute.to_sym)
        value = send(attribute)
        if value.class.name.start_with?("ActiveRedis::DirtyObjects")
          if value.dirty?
            @changed_attributes[attribute.to_s] = [value.original, value.changes]
          end
        end
      end
    end
  end
end