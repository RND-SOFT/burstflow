$:.push File.expand_path('lib', __dir__)

# Maintain your gem's version:
require 'burstflow/version'

Gem::Specification.new do |spec|
  spec.name          = 'burstflow'
  spec.version       = Burstflow::VERSION
  spec.authors       = ['Samoilenko Yuri']
  spec.email         = ['kinnalru@gmail.com']
  spec.summary       = 'Burstflow is a parallel workflow runner using ActiveRecord and ActiveJob'
  spec.description   = 'Burstflow is a parallel workflow runner using ActiveRecord and ActiveJob. It has dependency, result pipelining and suspend/resume ability'
  spec.homepage      = 'https://github.com/RnD-Soft/burstflow'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'activejob'
  spec.add_dependency 'activerecord'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'generator_spec'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
end
