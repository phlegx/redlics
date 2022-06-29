# frozen_string_literal: true

module Redlics
  # Time Frame class
  class TimeFrame
    # Gives read access to the listed instance variables.
    attr_reader :from, :to, :granularity

    # Initialization of a time frame object.
    #
    # @param context [Hash] the hash of a context defined in Redlics::CONTEXTS
    # @param time_object [Symbol] time object predefined in Redlics::TimeFrame.init_with_symbol
    # @param time_object [Hash] time object with keys `from` and `to`
    # @param time_object [Range] time object as range
    # @param time_object [Time] time object
    # @param options [Hash] configuration options
    # @return [Redlics::TimeFrame] time frame object
    def initialize(context, time_object, options = {})
      raise ArgumentError, 'TimeFrame should be initialized with Symbol, Hash, Range or Time' unless [Symbol, Hash, Range, Time].include?(time_object.class)
      @from, @to = self.send("init_with_#{time_object.class.name.demodulize.underscore}", time_object, context)
      @granularity = Granularity.validate(context, options[:granularity]).first
    end

    # Construct keys by time frame steps.
    # @return [Array] keys
    def splat
      [].tap do |keys|
        (from.to_i .. to.to_i).step(Redlics.config.granularities[@granularity][:step]) do |t|
          keys << (block_given? ? (yield Time.at(t)) : Time.at(t))
        end
      end
    end

    private

      # Initialize time frames `from` and `to` by time.
      #
      # @param time [Time] a time
      # @param context [Hash] the hash of a context defined in Redlics::CONTEXTS
      # @return [Array] with `from` and `to` time
      def init_with_time(time, context)
        [time.beginning_of_day, time.end_of_day]
      end

      # Initialize time frames `from` and `to` by symbol.
      #
      # @param symbol [Symbol] a time span
      # @param context [Hash] the hash of a context defined in Redlics::CONTEXTS
      # @return [Array] with `from` and `to` time
      def init_with_symbol(symbol, context)
        case symbol
        when :hour, :day, :week, :month, :year
          return 1.send(symbol).ago, Time.now
        when :today
          return Time.now.beginning_of_day, Time.now
        when :yesterday
          return 1.day.ago.beginning_of_day, 1.day.ago.end_of_day
        when :this_week
          return Time.now.beginning_of_week, Time.now
        when :last_week
          return 1.week.ago.beginning_of_week, 1.week.ago.end_of_week
        when :this_month
          return Time.now.beginning_of_month, Time.now
        when :last_month
          return 1.month.ago.beginning_of_month, 1.month.ago.end_of_month
        when :this_year
          return Time.now.beginning_of_year, Time.now
        when :last_year
          return 1.year.ago.beginning_of_year, 1.year.ago.end_of_year
        else
          return default(context), Time.now
        end
      end

      # Initialize time frames `from` and `to` by hash.
      #
      # @param hash [Hash] a time hash with keys `from` and `to`
      # @param context [Hash] the hash of a context defined in Redlics::CONTEXTS
      # @return [Array] with `from` and `to` time
      def init_with_hash(hash, context)
        [ hash[:from] && hash[:from].is_a?(String) && Time.parse(hash[:from]) || hash[:from] || default(context),
          hash[:to]   && hash[:to].is_a?(String)   && Time.parse(hash[:to])   || hash[:to]   || Time.now ]
      end

      # Initialize time frames `from` and `to` by hash.
      #
      # @param range [Range] a time range
      # @param context [Hash] the hash of a context defined in Redlics::CONTEXTS
      # @return [Array] with `from` and `to` time
      def init_with_range(range, context)
        init_with_hash({ from: range.first, to: range.last }, context)
      end

      # Get default granularity by given context.
      #
      # @param context [Hash] the hash of a context defined in Redlics::CONTEXTS
      # @return [ActiveSupport::TimeWithZone] a time
      def default(context)
        Redlics.config.granularities[Granularity.default(context).first][:step].ago
      end
  end
end
