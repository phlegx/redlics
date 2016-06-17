module Redlics
  class Query

    # Operation class
    class Operation

      # Include Redlics operators.
      include Redlics::Operators


      # Gives read access to the listed instance variables.
      attr_reader :namespaces


      # Initialization of a query operation object.
      #
      # @param operator [String] operator to calculate
      # @param queries [Array] queries to calculate with the given operator
      # @return [Redlics::Query::Operation] query operation object
      def initialize(operator, queries)
        @operator = operator.upcase.freeze
        @queries = queries.freeze
        @track_bits = nil
        @namespaces = []
        ObjectSpace.define_finalizer(self, self.class.finalize(namespaces)) if Redlics.config.auto_clean
      end


      # Get or process tracks on Redis.
      # @return [Integer] tracks result of given query operation
      def tracks
        @tracks ||= (
          Redlics.redis { |r| r.bitcount(@track_bits || traverse) }
        )
      end


      # Get or process track bits on Redis.
      # @return [String] key of track bits result
      def track_bits
        @track_bits ||= (
          keys = []
          track_bits_namespace = Key.unique_namespace
          @namespaces << track_bits_namespace
          if @operator == 'NOT'
            keys << Key.with_namespace(@queries[0].track_bits)
          else
            @queries.each { |q| keys << Key.with_namespace(q.track_bits) }
          end
          Redlics.script(Redlics::LUA_SCRIPT, [], ['operation'.to_msgpack, keys.to_msgpack,
                         { operator: @operator, dest: Key.with_namespace(track_bits_namespace) }.to_msgpack])
          track_bits_namespace
        )
      end


      # Check if object id exists in track bits.
      #
      # @param [Integer] the object id to check
      # @return [Boolean] true if exists, false if not
      def exists?(id)
        Redlics.redis { |r| r.getbit(@track_bits || traverse, id.to_i) } == 1
      end


      # Reset processed data (also operation keys on Redis).
      #
      # @param space [Symbol] define space to reset
      # @param space [String] define space to reset
      # @return [Boolean] true
      def reset!(space = nil)
        space = space.to_sym if space
        case space
        when :tree
          @queries.each { |q| q.reset!(:tree) }
          reset!
        else
          @tracks, @track_bits = nil, nil
          self.class.reset_redis_namespaces(@namespaces)
          @namespaces = []
        end
        return true
      end


      # Check if query operation is a leaf in the binary tree.
      # @return [Boolean] true if a leaf, false if not
      def is_leaf?
        is_a?(Redlics::Query::Operation) && @track_bits.nil?
      end


      # Singleton class
      class << self

        # Finalize query operation called from garbage collector.
        #
        # @param namespaces [Array] list of created operation keys in Redis
        # @return [Integer] result of Redis delete keys
        # @return [NilClass] nil if namespaces are empty
        def finalize(namespaces)
          proc { reset_redis_namespaces(namespaces) }
        end


        # Reset Redis created namespace keys.
        #
        # @param namespaces [Array] list of created operation keys in Redis
        # @return [Integer] result of Redis delete keys
        # @return [NilClass] nil if namespaces are empty
        def reset_redis_namespaces(namespaces)
          Redlics.redis { |r| r.del(namespaces) } if namespaces.any?
        end

      end


      private


        # Traverse query operation binary tree and calculate operation leafs.
        # @return [String] result operation key in Redis
        def traverse
          if @operator == 'NOT'
            @queries[0].traverse unless @queries[0].is_leaf?
            track_bits
          else
            @queries.each { |q| q.traverse unless q.is_leaf? }
            track_bits
          end
        end

    end
  end
end
