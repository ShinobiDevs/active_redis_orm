module ActiveRedis
  module DirtyObjects
    class Hash < ::Hash
      def self.[](*args)
        hash = super
        hash.original = hash.dup
        hash
      end

      attr_accessor :original

      def dirty?
        @original != self
      end

      def changes
        {additions: updated_keys, drops: dropped_keys, hash: self}
      end

      def dropped_keys
        @original.keys - self.keys
      end

      def updated_keys
        self.keys.select do |key|
          @original[key] != self[key]
        end
      end
    end
  end
end