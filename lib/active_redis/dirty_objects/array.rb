module ActiveRedis
  module DirtyObjects
    class Array < ::Array
      attr_reader :original
      def initialize(*args)
        super
        @original = dup
      end

      def dirty?
        @original != self
      end

      def changes
        {additions: self - @original, drops: @original - self}
      end
    end
  end
end