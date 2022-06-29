# frozen_string_literal: true

module Redlics
  # Query class
  class Query
    # Include Redlics operators.
    include Redlics::Operators

    # Gives read access to the listed instance variables.
    attr_reader :namespaces

    # Initialization of a query object
    #
    # @param event [String] event name with eventual Redis namespace separator
    # @param time_object [Symbol] time object predefined in Redlics::TimeFrame.init_with_symbol
    # @param time_object [Hash] time object with keys `from` and `to`
    # @param time_object [Range] time object as range
    # @param time_object [Time] time object
    # @param options [Hash] configuration options
    # @return [Redlics::Query] query object
    def initialize(event, time_object, options = {})
      @event = event.freeze
      @time_object = time_object.freeze
      @options = options
      @namespaces = []
      ObjectSpace.define_finalizer(self, self.class.finalize(namespaces)) if Redlics.config.auto_clean
    end

    # Get or process counts on Redis.
    # @return [Integer] count result of given query
    def counts
      @counts ||= (
        result = Redlics.script(Redlics::LUA_SCRIPT, [], ['counts'.to_msgpack, realize_counts!.to_msgpack,
                                { bucketized: Redlics.config.bucket }.to_msgpack])
        result.is_a?(Array) ? result.map(&:to_i).reduce(0, :+) : result.to_i
      )
    end

    # Get or process tracks on Redis.
    # @return [Integer] tracks result of given query
    def tracks
      @tracks ||= Redlics.redis { |r| r.bitcount(track_bits) }
    end

    # Get or process track bits on Redis.
    # @return [String] key of track bits result
    def track_bits
      @track_bits ||= (
        @track_bits_namespace = Key.unique_namespace
        @namespaces << @track_bits_namespace
        Redlics.script(Redlics::LUA_SCRIPT, [], ['operation'.to_msgpack, realize_tracks!.to_msgpack,
                       { operator: 'OR', dest: Key.with_namespace(@track_bits_namespace) }.to_msgpack])
        @track_bits_namespace
      )
    end

    # Check if object id exists in track bits.
    # @return [Boolean] true if exists, false if not
    # @return [NilClass] nil if no object id is given
    def exists?
      @exists ||= @options[:id] ? Redlics.redis { |r| r.getbit(track_bits, @options[:id]) } == 1 : nil
    end

    # Get or process counts and plot.
    #
    # @return [Hash] with date times and counts
    # @return [NilClass] nil if result has errors
    def plot_counts
      @plot_counts ||= (
        result = JSON.parse(
          Redlics.script(Redlics::LUA_SCRIPT, [], ['plot_counts'.to_msgpack, realize_counts!.to_msgpack,
                         { bucketized: Redlics.config.bucket }.to_msgpack])
        )
        format_plot(Redlics::CONTEXTS[:counter], result)
      )
    rescue JSON::ParserError
      nil
    end

    # Get or process tracks and plot.
    #
    # @return [Hash] with date times and counts
    # @return [NilClass] nil if result has errors
    def plot_tracks
      @plot_tracks ||= (
        result = JSON.parse(
        Redlics.script(Redlics::LUA_SCRIPT, [], ['plot_tracks'.to_msgpack, realize_tracks!.to_msgpack,
                       {}.to_msgpack])
        )
        format_plot(Redlics::CONTEXTS[:tracker], result)
      )
    rescue JSON::ParserError
      nil
    end

    # Get or process counts and show keys to analyze.
    # @return [Array] list of keys to analyze
    def realize_counts!
      @realize_counts ||= (
        keys = Key.timeframed(Redlics::CONTEXTS[:counter], @event, @time_object, @options)
        raise Exception::LuaRangeError if keys.length > 8000
        keys
      )
    end

    # Get or process tracks and show keys to analyze.
    # @return [Array] list of keys to analyze
    def realize_tracks!
      @realize_tracks ||= (
        keys = Key.timeframed(Redlics::CONTEXTS[:tracker], @event, @time_object, @options)
        raise Exception::LuaRangeError if keys.length > 8000
        keys
      )
    end

    # Reset processed data (also operation keys on Redis).
    #
    # @param space [Symbol] define space to reset
    # @param space [String] define space to reset
    # @return [Boolean] true
    def reset!(space = nil)
      space = space.to_sym if space
      case space
      when :counts, :plot_counts, :plot_tracks, :realize_counts, :realize_tracks
        instance_variable_set("@#{space}", nil)
      when :tracks, :exists
        instance_variable_set("@#{space}", nil)
        reset_track_bits
      when :counter
        @counts, @plot_counts, @realize_counts = [nil] * 3
      when :tracker
        @tracks, @exists, @plot_tracks, @realize_tracks = [nil] * 4
        reset_track_bits
      else
        @counts, @tracks, @exists, @plot_counts, @plot_tracks, @realize_counts, @realize_tracks = [nil] * 7
        reset_track_bits
        self.class.reset_redis_namespaces(@namespaces)
        @namespaces = []
      end
      return true
    end

    # Check if query is a leaf. A query is always a leaf.
    # This method is required for query operations.
    # @return [Boolean] true
    def is_leaf?
      true
    end

    # Singleton class
    class << self
      # Short query access to analyze data.
      #
      # @param *args [Array] list of arguments of the query
      # @return [Redlics::Query] instantiated query object
      def analyze(*args)
        options = args.last.instance_of?(Hash) ? args.pop : {}
        query = case args.size
                when 2
                  Query.new(args[0], args[1], options)
                when 3
                  Query.new(args[0], args[1], options.merge!({ id: args[2].to_i }))
                end
        return yield query if block_given?
        query
      end

      # Finalize query called from garbage collector.
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

      # Format plot result with time objects as keys.
      #
      # @param context [Hash] the hash of a context defined in Redlics::CONTEXTS
      # @param result [Hash] the result hash with Redis keys as hash keys
      # @return [Hash] the formatted result hash
      def format_plot(context, result)
        granularity = Granularity.validate(context, @options[:granularity]).first
        pattern = Redlics.config.granularities[granularity][:pattern]
        el = Key.bucketize?(context, @options) ? -2 : -1
        result.keys.each { |k|
          result[Time.strptime(k.split(Redlics.config.separator)[el], pattern)] = result.delete(k)
        }
        result
      end

      # Reset track bits (also operation key on Redis).
      # @return [NilClass] nil
      def reset_track_bits
        self.class.reset_redis_namespaces([@track_bits_namespace])
        @namespaces.delete(@track_bits_namespace)
        @track_bits, @track_bits_namespace = nil, nil
      end
  end
end
