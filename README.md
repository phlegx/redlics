# Redlics

[![Gem Version](https://badge.fury.io/rb/redlics.svg)](https://rubygems.org/gems/redlics)
[![Gem](https://img.shields.io/gem/dt/redlics.svg?maxAge=2592000)](https://rubygems.org/gems/redlics)
[![Build Status](https://secure.travis-ci.org/phlegx/redlics.svg?branch=master)](https://travis-ci.org/phlegx/redlics)
[![Code Climate](http://img.shields.io/codeclimate/github/phlegx/redlics.svg)](https://codeclimate.com/github/phlegx/redlics)
[![Inline Docs](http://inch-ci.org/github/phlegx/redlics.svg?branch=master)](http://inch-ci.org/github/phlegx/redlics)
[![Dependency Status](https://gemnasium.com/phlegx/redlics.svg)](https://gemnasium.com/phlegx/redlics)
[![License](https://img.shields.io/github/license/phlegx/redlics.svg)](http://opensource.org/licenses/MIT)

Redis analytics with tracks (using bitmaps) and counts (using buckets) encoding numbers in Redis keys and values.

## Features

* Tracking with bitmaps
* Counting with buckets
* High configurable
* Encode/decode numbers in Redis keys and values
* Very less memory consumption in Redis
* Support of time frames
* Uses Lua script for better performance
* Plot option for tracks and counts
* Keeps Redis clean
* and many more, see the [documentation](http://www.rubydoc.info/gems/redlics)

## Installation

**System Requirements:** Redis >= 2.8.18, Redis v3.x is recommended!

Add this line to your application's Gemfile:

```ruby
gem 'redlics'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install redlics

## Usage

### Configuration

The following configuration is the default configuration of Redlics. Store the configration code and load it at the beginning of Redlics use.
Rails users can create a file `redlics.rb` in `config/initializers` to load the own Redlics configuration.

```ruby
Redlics.configure do |config|
  config.pool_size = 5                              # Default connection pool size is 5
  config.pool_timeout = 5                           # Default connection pool timeout is 5
  config.namespace = 'rl'                           # Default Redis namespace is 'rl', short name saves memory
  config.redis = { url: 'redis://127.0.0.1:6379' }  # Default Redis configuration, see: https://github.com/redis/redis-rb/blob/master/lib/redis.rb
  config.silent = false                             # Silent Redis errors, default is false
  config.separator = ':'                            # Default Redis namespace separator, default is ':'
  config.bucket = true                              # Bucketize counter object ids, default is true
  config.bucket_size = 1000                         # Bucket size, best performance with bucket size 1000. See hash-max-ziplist-entries
  config.auto_clean = true                          # Auto remove operation keys from Redis
  config.encode = {                                 # Encode event ids or object ids
    events: true,
    ids: true
  }
  config.granularities = {
    minutely: { step: 1.minute, pattern: '%Y%m%d%H%m' },
    hourly:   { step: 1.hour,   pattern: '%Y%m%d%H' },
    daily:    { step: 1.day,    pattern: '%Y%m%d' },
    weekly:   { step: 1.week,   pattern: '%GW%V' },
    monthly:  { step: 1.month,  pattern: '%Y%m' },
    yearly:   { step: 1.year,   pattern: '%Y' }
  }
  config.counter_expirations = { minutely: 1.day, hourly: 1.week, daily: 3.months, weekly: 1.year, monthly: 1.year, yearly: 1.year }
  config.counter_granularity = :daily..:yearly
  config.tracker_expirations = { minutely: 1.day, hourly: 1.week, daily: 3.months, weekly: 1.year, monthly: 1.year, yearly: 1.year },
  config.tracker_granularity = :daily..:yearly
  config.operation_expiration = 1.day
end
```

#### Buckets

If Redlics is configured to use buckets, please configure Redis to allow an ideal size of list entries.

```ruby
# Redlics config
config.bucket = true
config.bucket_size = 1000
```

The Redis configuration can be found in file `redis.conf`. The default bucket size is 1000 and is an ideal size. Any higher size and
the HSET commands would cause noticeable CPU activity. The Redis setting `hash-max-ziplist-entries` configures the maximum number
of entries a hash can have while still being encoded efficiently.

```
# /etc/redis/redis.conf
hash-max-ziplist-entries 1024
hash-max-ziplist-value 64
```

Read more:
* [Special encoding of small aggregate data types](http://redis.io/topics/memory-optimization)
* [Storing hundreds of millions of simple key-value pairs in Redis](http://instagram-engineering.tumblr.com/post/12202313862/storing-hundreds-of-millions-of-simple-key-value)

##### Example

* **Id:** 1234
* **Bucket size**: 1000

results in:

* **Bucket nr.:** 1 (part of Redis key)
* **Bucket entry nr.:** 234 (part of Redis value as hash key)

#### Encoding

If Redlics is configured to encode events and object ids, all numbers are encoded to save memory.

```ruby
config.encode = {
  events: true,
  ids: true
}
```

##### Examples

Byte size reduction of id `1234` from 4 bytes to 2 bytes.

* Ids encoding

```ruby
Redlics::Key.encode(1234)
# => "2+"
```

* Event encoding

Encodes numbers in event names separated by the defined separator in the configuration.
**Event name:** `products:1234`, **encoded event:** `products:!k`.

### Counting

Counting an event can be done by call count with **arguments**, **hash parameters** or a **block**.

```ruby
# By arguments
Redlics.count('products:list')

# By hash parameters
Redlics.count(event: 'products:list', id: 1234)

# By block
Redlics.count do |c|
  c.event = 'products:list'
  c.id = 1234

  # Count this event in the past
  c.past = 3.days.ago

  # Count granularity for this event: Symbol, String, Array or Range
  c.granularity = :daily..:monthly
  # c.granularity = :daily
  # c.granularity = [:daily, :monthly]

  # Expire (delete) count for this event for specific granularities after defined period.
  c.expiration_for = { daily: 6.days, monthly: 2.months }
end
```

**Parameters**

* **event:** event name **(required)**.
* **id:** object id (optional), e.g. user id
* **past:** time object (optional), if not set `Time.now` is used.
* **granularity:** granularities defined in configuration (optional), if not set `config.counter_granularity` is used.
* **expiration_for:** expire count for given granularities (optional), if not set `config.counter_expirations` is used.

### Tracking

Tracking an event can be done by call track with **arguments**, **hash parameters** or a **block**.

```ruby
# By arguments
Redlics.track('products:list', 1234)

# By hash parameters
Redlics.track(event: 'products:list', id: 1234)

# By block
Redlics.track do |t|
  t.event = 'products:list'
  t.id = 1234

  # Track this event in the past
  t.past = 3.days.ago

  # Track granularity for this event: Symbol, String, Array or Range
  t.granularity = :daily..:monthly
  # t.granularity = :daily
  # t.granularity = [:daily, :monthly]

  # Expire (delete) tracking for this event for specific granularities after defined period.
  t.expiration_for = { daily: 6.days, monthly: 2.months }
end
```

**Parameters**

* **event:** event name **(required)**.
* **id:** object id **(required)**, e.g. user id
* **past:** time object (optional), if not set `Time.now` is used.
* **granularity:** granularities defined in configuration (optional), if not set `config.counter_granularity` is used.
* **expiration_for:** expire track for given granularities (optional), if not set `config.counter_expirations` is used.

### Analyze

To analyze recorded data an analyzable query object must be defined first.

```ruby
a1 = Redlics.analyze('products:list', :today)

# Examples
a2 = Redlics.analyze('products:list', :today, granularity: :minutely)
a3 = Redlics.analyze('products:list', :today, id: 1234)
```

**Parameters**

* **event:** event name **(required)**.
* **time:** time object **(required)**, can be:
  * **a symbol:** predefined in Redlics::TimeFrame.init_with_symbol
    * e.g. *:hour, :day, :week, :month, :year, :today, :yesterday, :this_week, :last_week, :this_month, :last_month, :this_year, :last_year*
  * **a hash:** with keys `from` and `to`
    * e.g. `{ from: 30.days.ago, to: Time.now}`
  * **a range:** defined as a range
    * e.g. `30.days.ago..Time.now`
  * **a time:** simple time object
    * e.g. `Time.new(2016, 1, 12)` or `1.day.ago.to_time`
* **Options:**
  * **id:** object id, e.g. user id
  * **granularity:** one granularitiy defined in configuration (optional), if not set first element of `config.counter_granularity` is used.

Analyzable query objects can be used to analyze **counts** and **tracks**.
Queries are not *"realized"* until an action is performed:

#### Counts

```ruby
# Check how many counts has been recorded.
a1.counts

# Use this method to get plot-friendly data for graphs.
a1.plot_counts

# See what's under the hood. No Redis access.
a1.realize_counts!
```

#### Tracks

```ruby
# Check how many unique tracks has been recorded.
a1.tracks

# Check if given id exists in the tracks result.
a1.exists?

# Use this method to get plot-friendly data for graphs.
a1.plot_tracks

# See what's under the hood. No Redis access.
a1.realize_tracks!
```

#### Reset

Reset is required to keep clean redis operation results. To calculate counts and tracks operations are stored in Redis.
It is possible to delete this operation result keys in Redis manually or let the Ruby garbage collector clean redis before the
analyzable query objects are destructed (configuration `config.auto_clean`). The third way is hard coded and uses an expiration
time in Redis for that given operation result keys. The expiration time for operations can be configured with `config.operation_expiration`.`

```ruby
a1.reset!
```

Partial resets are also possible by pass a `space` argument as symbol:

```ruby
# :counter, :tracker, :counts, :tracks, :exists,
# :plot_counts, :plot_tracks, :realize_counts, :realize_tracks
a1.reset!(:counter)
a1.reset!(:tracker)
```

**It is recommended to do a reset if the analyzable query object is no more needed!**

The analyzable query objects can also be created and used in a block.

```ruby
Redlics.analyze('products:list', :today) do |a|
  a.tracks
  # ...
  a.reset!
end
```

### Operators

Analyzable query objects can be calculated also using operators (for tracking data). The following operators are available:

* **AND** (`&`)
* **OR** (`|`),
* **NOT** (`~`, `-`)
* **XOR** (`^`)
* **PLUS** (`+`)
* **MINUS** (`-`)

Assuming users has been tracked for the actions `products:list, products:featured, logged_in`, then it is
possible to use operators to check users that:

* has viewed the products list
* and the featured products list
* but not logged in today

```ruby
# Create analyzable query objects
a1 = Redlics.analyze('products:list', :today)
a2 = Redlics.analyze('products:featured', :today)
a3 = Redlics.analyze('logged_in', :today)

# The operation
o = (( a1 & a2) - a3)

# To check how many users are in this result set.
o.tracks

# To check if a user is in this result set.
o.exists?(1234)

# Clean up complete operation results.
o.reset!(:tree)
```

### Tips and hints

#### Granularities

* You should be aware that there is a close relation between counting, tracking and querying in regards to granularities.
* When querying, make sure to tracking in the same granularity.
* If you are tracking in the range of `:daily..:monthly` then you can only query in that range (or you will get wrong results).
* Another possible error you should be aware of is when querying for a time frame that is not correlated with the granularity.

#### Buckets

* Use buckets if you have many counters to save memory.
* 1000 is the ideal bucket size.

#### Encoding

* Use event and ids encoding if you have many counters to save memory.

#### Namespaces

Keys in Redis look like this:

```ruby
# Tracker
'rl:t:products:list:2016'

# Counter without buckets (unencoded)
'rl:c:products:list:2016:1234'

# Counter without buckets (encoded)
'rl:c:products:list:2016:!k'

# Counter with buckets (unencoded, 234 is value of key)
'rl:c:products:list:2016:1' => '234'

# Counter with buckets (encoded, 3k is value of key)
'rl:c:products:list:2016:2' => '3k'

# Operation
'rl:o:f56fa42d-1e85-4e2f-b8c8-a0f9b5bee5d0'
```

## Contributors

* Inspired by Minuteman [github.com/elcuervo/minuteman](https://github.com/elcuervo/minuteman).
* Inspired by Btrack [github.com/chenfisher/Btrack](https://github.com/chenfisher/Btrack).
* Inspired by Counterman [github.com/maccman/counterman](https://github.com/maccman/counterman).

## Contributing

1. Fork it ( https://github.com/[your-username]/redlics/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

The MIT License

Copyright (c) 2015 Phlegx Systems OG

