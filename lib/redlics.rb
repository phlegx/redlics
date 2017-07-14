require 'active_support/core_ext/module/delegation'
require 'active_support/time'
require 'msgpack'
require 'ostruct'
require 'redlics/version'
require 'redlics/config'
require 'redlics/exception'
require 'redlics/connection'
require 'redlics/granularity'
require 'redlics/key'
require 'redlics/time_frame'
require 'redlics/counter'
require 'redlics/tracker'
require 'redlics/operators'
require 'redlics/query'
require 'redlics/query/operation'


# Redlics namespace
module Redlics

  extend self

  # Delegate methods to right objects.
  delegate :count, to: Counter
  delegate :track, to: Tracker
  delegate :analyze, to: Query


  # Get or initialize the Redis connection.
  # @return [Object] redis connection
  def redis
    raise ArgumentError, 'requires a block' unless block_given?
    redis_pool.with do |conn|
      retryable = true
      begin
        yield conn
      rescue Redis::BaseError => e
        raise e unless config.silent
      rescue Redis::CommandError => ex
        (conn.disconnect!; retryable = false; retry) if retryable && ex.message =~ /READONLY/
        raise unless config.silent
      end
    end
  end


  # Load Lua script file and arguments in Redis.
  #
  # @param file [String] absolute path to the Lua script file
  # @param *args [Array] list of arguments for Redis evalsha
  # @return [String] Lua script result
  def script(file, *args)
    begin
      cache = LUA_CACHE[redis { |r| r.client.options[:url] }]
      if cache.key?(file)
        sha = cache[file]
      else
        src = File.read(file)
        sha = redis { |r| r.redis.script(:load, src) }
        cache[file] = sha
      end
      redis { |r| r.evalsha(sha, *args) }
    rescue RuntimeError
      case $!.message
      when Exception::ErrorPatterns::NOSCRIPT
        LUA_CACHE[redis { |r| r.client.options[:url] }].clear
        retry
      else
        raise $! unless config.silent
      end
    end
  end


  # Get or initialize Redlics config.
  # @return [OpenStruct] Redlics configuration
  def config
    @config ||= Redlics::Config.new
  end


  # Set configuration of Redlics in a block.
  # @return [OpenStruct] Redlics configuration
  def configure
    yield config if block_given?
  end


  private

    # Get or initialize the Redis connection pool.
    # @return [ConnectionPool] redis connection pool
    def redis_pool
      @redis ||= Redlics::Connection.create(config.to_h)
    end

end

