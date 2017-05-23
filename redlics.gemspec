# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'redlics/version'


Gem::Specification.new do |spec|
  spec.name          = 'redlics'
  spec.version       = Redlics::VERSION
  spec.authors       = ['Egon Zemmer']
  spec.email         = ['office@phlegx.com']
  spec.date          = Time.now.utc.strftime('%Y-%m-%d')
  spec.homepage      = "http://github.com/phlegx/#{spec.name}"

  spec.summary       = %q{Redis analytics with tracks and counts.}
  spec.description   = %q{Redis analytics with tracks (using bitmaps) and counts (using buckets)
                          encoding numbers in Redis keys and values.}
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.test_files    = Dir.glob('test/*_test.rb')
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.0.0'
  spec.add_dependency 'connection_pool', '~> 2.2'
  spec.add_dependency 'redis', '~> 3.2'
  spec.add_dependency 'redis-namespace', '~> 1.5'
  spec.add_dependency 'activesupport', '>= 4.2', '< 5.2'
  spec.add_dependency 'msgpack', '>= 0.7.2', '< 2.0'

  spec.add_development_dependency 'rake', '~> 12.0'
  spec.add_development_dependency 'minitest', '~> 5.8'
end
