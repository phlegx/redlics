# frozen_string_literal: true

module Redlics
  # Granularity namespace
  module Granularity
    extend self

    # Validate granularities by given context.
    #
    # @param context [Hash] the hash of a context defined in Redlics::CONTEXTS
    # @param granularities [Range] granularity range
    # @param granularities [String] single granularity
    # @param granularities [Array] granularity array
    # @return [Array] includes all valid granularities
    def validate(context, granularities)
      check(granularities) || default(context)
    end

    # Get default granularities by given context.
    #
    # @param context [Hash] the hash of a context defined in Redlics::CONTEXTS
    # @return [Array] includes all valid default granularities
    def default(context)
      check(Redlics.config["#{context[:long]}_granularity"]) || [Redlics.config.granularities.keys.first]
    end

    private

      # Check if granularities are defined in the configuration.
      #
      # @param granularities [Range] granularity range
      # @param granularities [String] single granularity
      # @param granularities [Array] granularity array
      # @return [Array] includes all valid granularities
      def check(granularities)
        keys = Redlics.config.granularities.keys
        checked = case granularities
                  when Range
                    keys[keys.index(granularities.first.to_sym)..keys.index(granularities.last.to_sym)]
                  when Array
                    [granularities.map(&:to_sym)].flatten & keys
                  else
                    [granularities && granularities.to_sym].flatten & keys
                  end
        checked.any? ? checked : nil
      end
  end
end
