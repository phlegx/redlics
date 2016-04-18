module Redlics

  # Redlics constants.
  LUA_CACHE      = Hash.new { |h, k| h[k] = Hash.new }
  LUA_SCRIPT     = File.expand_path('../lua/script.lua', __FILE__).freeze
  CONTEXTS       = { counter: { short: :c, long: :counter }, tracker: { short: :t, long: :tracker }, operation: { short: :o, long: :operation } }.freeze


  # Configuration class
  class Config

    # Initialization with default configuration.
    #
    # Configure Redis:
    # /etc/redis/redis.conf
    # hash-max-ziplist-entries 1024
    # hash-max-ziplist-value 64
    #
    # @return [OpenStruct] default configuration
    def initialize
      @config = OpenStruct.new(
        pool_size: 5,                              # Default connection pool size is 5
        pool_timeout: 5,                           # Default connection pool timeout is 5
        namespace: 'rl',                           # Default Redis namespace is 'rl', short name saves memory
        redis: { url: 'redis://127.0.0.1:6379' },  # Default Redis configuration
        silent: false,                             # Silent Redis errors, default is false
        separator: ':',                            # Default Redis namespace separator, default is ':'
        bucket: true,                              # Bucketize counter object ids, default is true
        bucket_size: 1000,                         # Bucket size, best performance with bucket size 1000. See hash-max-ziplist-entries
        auto_clean: true,                          # Auto remove operation keys from Redis
        encode: {                                  # Encode event ids or object ids
          events: true,
          ids: true
        },
        granularities: {
          minutely: { step: 1.minute, pattern: '%Y%m%d%H%m' },
          hourly:   { step: 1.hour,   pattern: '%Y%m%d%H' },
          daily:    { step: 1.day,    pattern: '%Y%m%d' },
          weekly:   { step: 1.week,   pattern: '%GW%V' },
          monthly:  { step: 1.month,  pattern: '%Y%m' },
          yearly:   { step: 1.year,   pattern: '%Y' }
        },
        counter_expirations: { minutely: 1.day, hourly: 1.week, daily: 3.months, weekly: 1.year, monthly: 1.year, yearly: 1.year },
        counter_granularity: :daily..:yearly,
        tracker_expirations: { minutely: 1.day, hourly: 1.week, daily: 3.months, weekly: 1.year, monthly: 1.year, yearly: 1.year },
        tracker_granularity: :daily..:yearly,
        operation_expiration: 1.day
      )
    end


    # Send missing methods to the OpenStruct configuration.
    #
    # @param method [String] the missing method name
    # @param *args [Array] list of arguments of the missing method
    # @return [Object] a configuration parameter
    def method_missing(method, *args, &block)
      @config.send(method, *args, &block)
    end

  end
end
