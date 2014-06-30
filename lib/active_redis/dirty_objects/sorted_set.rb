module ActiveRedis
  module DirtyObjects
    class SortedSet < ActiveRedis::DirtyObjects::Array
      attr_accessor :hash
      attr_reader :original

      def []=(score, value)
        self.push(score)
        @hash ||= {}
        @hash[value] = score
      end

      def changes
        super.merge(hash: @hash)
      end
    end
  end
end