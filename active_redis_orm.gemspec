# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'active_redis/version'

Gem::Specification.new do |spec|
  spec.name          = "active_redis_orm"
  spec.version       = ActiveRedisOrm::VERSION
  spec.authors       = ["Tom Caspy"]
  spec.email         = ["tom@tikalk.com"]
  spec.summary       = %q{ActiveRedis is an ORM for redis written in Ruby.}
  spec.description   = %q{ActiveRedis is a Ruby ORM for Redis, using ActiveModel, heavily influenced by the ActiveRecord and Mongoid gems}
  spec.homepage      = "https://github.com/SpotIM/active_redis_orm"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_dependency "redis"
  spec.add_dependency "redis-objects"
  spec.add_dependency "activemodel"
  spec.add_dependency "activesupport"
end
