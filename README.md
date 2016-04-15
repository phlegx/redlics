# Redlics

[![Gem Version](https://badge.fury.io/rb/redlics.svg)](https://rubygems.org/gems/redlics)
[![Build Status](https://secure.travis-ci.org/phlegx/redlics.svg?branch=master)](https://travis-ci.org/phlegx/redlics)
[![Code Climate](http://img.shields.io/codeclimate/github/phlegx/redlics.svg)](https://codeclimate.com/github/phlegx/redlics)
[![Inline Docs](http://inch-ci.org/github/phlegx/redlics.svg?branch=master)](http://inch-ci.org/github/phlegx/redlics)
[![Dependency Status](https://gemnasium.com/phlegx/redlics.svg)](https://gemnasium.com/phlegx/redlics)
[![License](https://img.shields.io/github/license/phlegx/redlics.svg)](http://opensource.org/licenses/MIT)

Redis analytics with tracks (using bitmaps) and counts (using buckets) encoding numbers in Redis keys and values.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'redlics'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install redlics

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
* and many more

## Usage

Coming soon...

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

