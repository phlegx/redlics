module Redlics

  # Key namespace
  module Key

    extend self


    # Construct the key name with given parameters.
    #
    # @param context [Hash] the hash of a context defined in Redlics::CONTEXTS
    # @param event [String] event name with eventual Redis namespace separator
    # @param granularity [Symbol] existing granularity
    # @param past [Time] a time object
    # @param options [Hash] configuration options
    # @return [String] unbucketized key name
    # @return [Array] bucketized key name
    def name(context, event, granularity, past, options = {})
      past ||= Time.now
      granularity = Granularity.validate(context, granularity).first
      event = encode_event(event) if Redlics.config.encode[:events]
      key = "#{context[:short]}#{Redlics.config.separator}#{event}#{Redlics.config.separator}#{time_format(granularity, past)}"
      key = with_namespace(key) if options[:namespaced]
      return bucketize(key, options[:id]) if bucketize?(context, options)
      return unbucketize(key, options[:id]) if context[:long] == :counter && !options[:id].nil?
      key
    end


    # Construct an array with all keys of a time frame in a given granularity.
    #
    # @param context [Hash] the hash of a context defined in Redlics::CONTEXTS
    # @param event [String] event name with eventual Redis namespace separator
    # @param time_object [Symbol] time object predefined in Redlics::TimeFrame.init_with_symbol
    # @param time_object [Hash] time object with keys `from` and `to`
    # @param time_object [Range] time object as range
    # @param time_object [Time] time object
    # @param options [Hash] configuration options
    # @return [Array] array with all keys of a time frame in a given granularity
    def timeframed(context, event, time_object, options = {})
      options = { namespaced: true }.merge(options)
      timeframe = TimeFrame.new(context, time_object, options)
      timeframe.splat do |time|
        name(context, event, timeframe.granularity, time, options)
      end
    end


    # Prepend namespace to a key.
    #
    # @param key [String] the key name
    # @return [String] the key name with prepended namespace
    def with_namespace(key)
      return key unless Redlics.config.namespace.length > 0
      return key if key.split(Redlics.config.separator).first == Redlics.config.namespace.to_s
      "#{Redlics.config.namespace}#{Redlics.config.separator}#{key}"
    end


    # Encode a number with a mapping table.
    #
    # @param number [Integer] the number to encode
    # @return [String] the encoded number as string
    def encode(number)
      encoded = ''
      number = number.to_s
      number = (number.size % 2) != 0 ? "0#{number}" : number
      token = 0
      while token <= number.size - 1
        encoded += encode_map[number[token..token+1].to_i.to_s.to_sym].to_s
        token += 2
      end
      encoded
    end


    # Decode a number with a mapping table.
    #
    # @param string [String] the string to encode
    # @return [Integer] the decoded string as integer
    def decode(string)
      decoded = ''
      string = string.to_s
      token = 0
      while token <= string.size - 1
        number = decode_map[string[token].to_s.to_sym].to_s
        decoded += number.size == 1 ? "0#{number}" : number
        token += 1
      end
      decoded.to_i
    end


    # Check if a key exists in Redis.
    #
    # @param string [String] the key name to check
    # @return [Boolean] true id key exists, false if not
    def exists?(key)
      Redlics.redis.exists(key) == 1
    end


    # Check if Redlics can bucketize.
    #
    # @param context [Hash] the hash of a context defined in Redlics::CONTEXTS
    # @param options [Hash] configuration options
    # @return [Boolean] true if can bucketize, false if not
    def bucketize?(context, options = {})
      context[:long] == :counter && Redlics.config.bucket && !options[:id].nil?
    end


    # Create a unique operation key in Redis.
    # @return [String] the created unique operation key
    def unique_namespace
      loop do
        ns = operation
        unless exists?(ns)
          Redlics.redis.pipelined do |redis|
            redis.set(ns, 0)
            redis.expire(ns, Redlics.config.operation_expiration)
          end
          break ns
        end
      end
    end


    private

      # Create a operation key.
      # @return [String] the created operation key
      def operation
        "#{Redlics::CONTEXTS[:operation][:short]}#{Redlics.config.separator}#{SecureRandom.uuid}"
      end


      # Get the time format pattern of a granularity.
      #
      # @param granularity [Symbol] existing granularity
      # @param past [Time] a time object
      # @return [String] pattern of defined granularity
      def time_format(granularity, past)
        past.strftime(Redlics.config.granularities[granularity][:pattern])
      end


      # Encode ids in event names.
      #
      # @param event [String] event name with eventual Redis namespace separator
      # @return [String] event name with encoded ids
      def encode_event(event)
        event.to_s.split(Redlics.config.separator).map { |v| v.match(/\A\d+\z/) ? encode(v) : v }.join(Redlics.config.separator)
      end


      # Bucketize key name with id.
      #
      # @param key [String] key name
      # @param id [Integer] object id
      # @return [Array] bucketized key name and value
      def bucketize(key, id)
        bucket = id.to_i / Redlics.config.bucket_size.to_i
        value = id.to_i % Redlics.config.bucket_size.to_i
        if Redlics.config.encode[:ids]
          bucket = encode(bucket)
          value = encode(value)
        end
        ["#{key}#{Redlics.config.separator}#{bucket}", value]
      end


      # Unbucketize key name with id. Encode the id if configured to encode.
      #
      # @param key [String] key name
      # @param id [Integer] object id
      # @return [String] unbucketized key name with eventual encoded object id
      def unbucketize(key, id)
        id = encode(id) if Redlics.config.encode[:ids]
        "#{key}#{Redlics.config.separator}#{id}"
      end


      # Defined encode map.
      # @return [Hash] the encode map with numbers as keys
      def encode_map
        @encode_map ||= replace_separator_encode({
          '0': '1', '1': '2', '2': '3', '3': '4', '4': '5', '5': '6', '6': '7', '7': '8', '8': '9', '9': '0', '10': '-',
          '11': '=', '12': '!', '13': '@', '14': '#', '15': '$', '16': '%', '17': '^', '18': '&', '19': '*', '20': '(',
          '21': ')', '22': '_', '23': '+', '24': 'a', '25': 'b', '26': 'c', '27': 'd', '28': 'e', '29': 'f', '30': 'g',
          '31': 'h', '32': 'i', '33': 'j', '34': 'k', '35': 'l', '36': 'm', '37': 'n', '38': 'o', '39': 'p', '40': 'q',
          '41': 'r', '42': 's', '43': 't', '44': 'u', '45': 'v', '46': 'w', '47': 'x', '48': 'y', '49': 'z', '50': 'A',
          '51': 'B', '52': 'C', '53': 'D', '54': 'E', '55': 'F', '56': 'G', '57': 'H', '58': 'I', '59': 'J', '60': 'K',
          '61': 'L', '62': 'M', '63': 'N', '64': 'O', '65': 'P', '66': 'Q', '67': 'R', '68': 'S', '69': 'T', '70': 'U',
          '71': 'V', '72': 'W', '73': 'X', '74': 'Y', '75': 'Z', '76': '[', '77': ']', '78': '\\', '79': ';', '80': ',',
          '81': '.', '82': '/', '83': '{', '84': '}', '85': '|', '86': '§', '87': '<', '88': '>', '89': '?', '90': '`',
          '91': '~', '92': 'ä', '93': 'Ä', '94': 'ü', '95': 'Ü', '96': 'ö', '97': 'Ö', '98': 'é', '99': 'É' }).freeze
      end


      # Defined decode map.
      # @return [Hash] the decode map with numbers as values
      def decode_map
        @decode_map ||= replace_separator_decode({
          '1': '0', '2': '1', '3': '2', '4': '3', '5': '4', '6': '5', '7': '6', '8': '7', '9': '8', '0': '9', '-': '10',
          '=': '11', '!': '12', '@': '13', '#': '14', '$': '15', '%': '16', '^': '17', '&': '18', '*': '19', '(': '20',
          ')': '21', '_': '22', '+': '23', 'a': '24', 'b': '25', 'c': '26', 'd': '27', 'e': '28', 'f': '29', 'g': '30',
          'h': '31', 'i': '32', 'j': '33', 'k': '34', 'l': '35', 'm': '36', 'n': '37', 'o': '38', 'p': '39', 'q': '40',
          'r': '41', 's': '42', 't': '43', 'u': '44', 'v': '45', 'w': '46', 'x': '47', 'y': '48', 'z': '49', 'A': '50',
          'B': '51', 'C': '52', 'D': '53', 'E': '54', 'F': '55', 'G': '56', 'H': '57', 'I': '58', 'J': '59', 'K': '60',
          'L': '61', 'M': '62', 'N': '63', 'O': '64', 'P': '65', 'Q': '66', 'R': '67', 'S': '68', 'T': '69', 'U': '70',
          'V': '71', 'W': '72', 'X': '73', 'Y': '74', 'Z': '75', '[': '76', ']': '77', '\\': '78', ';': '79', ',': '80',
          '.': '81', '/': '82', '{': '83', '}': '84', '|': '85', '§': '86', '<': '87', '>': '88', '?': '89', '`': '90',
          '~': '91', 'ä': '92', 'Ä': '93', 'ü': '94', 'Ü': '95', 'ö': '96', 'Ö': '97', 'é': '98', 'É': '99' }).freeze
      end


      # Replace defined separator in configuration from the encode map.
      #
      # @param map [Hash] encode map hash
      # @return [Hash] encode map hash without defined separator in configuration.
      def replace_separator_encode(map)
        unless Redlics.config.separator == ':'
          key = map.key(Redlics.config.separator)
          map[key] = ':' if key
        end
        map
      end


      # Replace defined separator in configuration from the decode map.
      #
      # @param map [Hash] decode map hash
      # @return [Hash] decode map hash without defined separator in configuration.
      def replace_separator_decode(map)
        unless Redlics.config.separator == ':'
          key = Redlics.config.separator.to_s.to_sym
          map[':'.to_sym] = map.delete(key) if map.key?(key)
        end
        map
      end

  end
end
