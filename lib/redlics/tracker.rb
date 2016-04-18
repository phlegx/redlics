module Redlics

  # Tracker class
  module Tracker

    # Context constant for given class.
    CONTEXT = Redlics::CONTEXTS[:tracker].freeze

    extend self


    # Track for a given event and object id with options.
    #
    # @param *args [Array] list of arguments for track
    # @return [Array] list of tracked granularities
    def track(*args, &block)
      return track_with_block(&block) if block_given?
      return track_with_hash(args.first) if args.first.is_a?(Hash)
      track_with_args(*args)
    end


    private

      # Track with hash.
      #
      # @param options [Hash] configuration options
      # @return [Array] list of tracked granularities
      def track_with_hash(options)
        Granularity.validate(CONTEXT, options[:granularity]).each do |granularity|
          key = Key.name(CONTEXT, options[:event], granularity, options[:past])
          Redlics.redis.pipelined do |redis|
            redis.setbit(key, options[:id].to_i, 1)
            redis.expire(key, options[:expiration_for] && options[:expiration_for][granularity] || Redlics.config.tracker_expirations[granularity])
          end
        end
      end


      # Track with hash.
      #
      # @param [&Block] a block with configuration options
      # @return [Array] list of tracked granularities
      def track_with_block
        yield options = OpenStruct.new
        track_with_hash(options.to_h)
      end


      # Track with hash.
      #
      # @param *args [Array] list of arguments for track
      # @return [Array] list of tracked granularities
      def track_with_args(*args)
        options = args.last.instance_of?(Hash) ? args.pop : {}
        options.merge!({
          event: args[0],
          id: args[1]
        })
        track_with_hash(options)
      end

  end
end
