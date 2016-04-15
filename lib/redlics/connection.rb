require 'connection_pool'
require 'redis'
require 'redis/namespace'


module Redlics

  # Connection namespace
  module Connection

    extend self


    # Create a new connection pool for Redis connection.
    #
    # @param options [Hash] configuration options
    # @return [ConnectionPool] Redlics connection pool
    def create(options = {})
      ConnectionPool.new(pool_options(options)) do
        build_connection(options)
      end
    end


    private

      # Set connection pool options.
      #
      # @param options [Hash] configuration options
      # @return [Hash] connection pool options
      def pool_options(options)
        { size:    options[:pool_size],
          timeout: options[:pool_timeout] }
      end


      # Build Redis connection with options.
      #
      # @param options [Hash] configuration options
      # @return [Redis] Redis connection
      # @return [Redis::Namespace] Redis namespaced connection
      def build_connection(options)
        namespace = options[:namespace]
        connection = Redis.new(redis_opts(options))
        if namespace
          Redis::Namespace.new(namespace, redis: connection)
        else
          connection
        end
      end


      # Client options provided by redis-rb
      # @see https://github.com/redis/redis-rb/blob/master/lib/redis.rb
      #
      # @param options [Hash] options
      # @option options [String] :url (value of the environment variable REDIS_URL) a Redis URL, for a TCP connection: `redis://:[password]@[hostname]:[port]/[db]` (password, port and database are optional), for a unix socket connection: `unix://[path to Redis socket]`. This overrides all other options.
      # @option options [String] :host ("127.0.0.1") server hostname
      # @option options [Fixnum] :port (6379) server port
      # @option options [String] :path path to server socket (overrides host and port)
      # @option options [Float] :timeout (5.0) timeout in seconds
      # @option options [Float] :connect_timeout (same as timeout) timeout for initial connect in seconds
      # @option options [String] :password Password to authenticate against server
      # @option options [Fixnum] :db (0) Database to select after initial connect
      # @option options [Symbol] :driver Driver to use, currently supported: `:ruby`, `:hiredis`, `:synchrony`
      # @option options [String] :id ID for the client connection, assigns name to current connection by sending `CLIENT SETNAME`
      # @option options [Hash, Fixnum] :tcp_keepalive Keepalive values, if Fixnum `intvl` and `probe` are calculated based on the value, if Hash `time`, `intvl` and `probes` can be specified as a Fixnum
      # @option options [Fixnum] :reconnect_attempts Number of attempts trying to connect
      # @option options [Boolean] :inherit_socket (false) Whether to use socket in forked process or not
      # @option options [Array] :sentinels List of sentinels to contact
      # @option options [Symbol] :role (:master) Role to fetch via Sentinel, either `:master` or `:slave`
      def redis_opts(options)
        opts = options[:redis]
        opts[:driver] ||= 'ruby'
        opts
      end

  end
end
