module Redlics

  # Exception namespace
  module Exception

    # Error Pattern namespace
    module ErrorPatterns
      NOSCRIPT = /^NOSCRIPT/.freeze
    end


    # Lua Range Error class
    #
    # Maximal Lua stack size for the method `unpack` is by default 8000.
    # To change this parameter in Redis an own make and build of Redis is needed.
    # @see https://github.com/antirez/redis/blob/3.2/deps/lua/src/luaconf.h
    class LuaRangeError < StandardError;

      # Initialization with default error message.
      #
      # @param msq [String] the error message
      # @return [Redlics::Exception::LuaRangeError] error message
      def initialize(msg = 'Too many keys (max. 8000 keys defined by LUAI_MAXCSTACK)')
        super(msg)
      end

    end

  end
end
