module Redlics

  # Counter class
  module Counter

    # Context constant for given class.
    CONTEXT = Redlics::CONTEXTS[:counter].freeze

    extend self


    # Count for a given event and object id with options.
    #
    # @param *args [Array] list of arguments for count
    # @return [Array] list of counted granularities
    def count(*args, &block)
      return count_with_block(&block) if block_given?
      return count_with_hash(args.first) if args.first.is_a?(Hash)
      count_with_args(*args)
    end


    private

      # Count with hash.
      #
      # @param options [Hash] configuration options
      # @return [Array] list of counted granularities
      def count_with_hash(options)
        options[:id] = options[:id].to_i unless options[:id].nil?
        Granularity.validate(CONTEXT, options[:granularity]).each do |granularity|
          opt = options.clone.merge(granularity: granularity)
          if Redlics.config.bucket && opt[:id]
            count_by_hash(opt)
          else
            count_by_key(opt)
          end
        end
      end


      # Count with hash.
      #
      # @param [&Block] a block with configuration options
      # @return [Array] list of counted granularities
      def count_with_block
        yield options = OpenStruct.new
        count_with_hash(options.to_h)
      end


      # Count with hash.
      #
      # @param *args [Array] list of arguments for count
      # @return [Array] list of counted granularities
      def count_with_args(*args)
        options = args.last.instance_of?(Hash) ? args.pop : {}
        options.merge!(event: args[0])
        count_with_hash(options)
      end


      # Count by hash.
      #
      # @param options [Hash] configuration options
      # @return [Array] result of pipelined redis commands
      def count_by_hash(options)
        granularity = options[:granularity]
        key = Key.name(CONTEXT, options[:event], granularity, options[:past], { id: options[:id], bucketized: true })
        Redlics.redis.pipelined do |redis|
          redis.hincrby(key[0], key[1], 1)
          redis.expire(key[0], (options[:expiration_for] && options[:expiration_for][granularity] || Redlics.config.counter_expirations[granularity]).to_i)
        end
      end


      # Count by key.
      #
      # @param options [Hash] configuration options
      # @return [Array] result of pipelined redis commands
      def count_by_key(options)
        granularity = options[:granularity]
        key = Key.name(CONTEXT, options[:event], granularity, options[:past], { id: options[:id], bucketized: false })
        Redlics.redis.pipelined do |redis|
          redis.incr(key)
          redis.expire(key, (options[:expiration_for] && options[:expiration_for][granularity] || Redlics.config.counter_expirations[granularity]).to_i)
        end
      end

  end
end
