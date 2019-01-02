lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = 'burstflow'
  spec.version       = '0.1.0'
  spec.authors       = ['Samoilenko Yuri']
  spec.email         = ['kinnalru@gmail.com']
  spec.summary       = 'Burst is a parallel workflow runner using ActiveRecord and ActiveJob'
  spec.description   = 'Burst is a parallel workflow runner using ActiveRecord and ActiveJob. It has dependency, result pipelining and suspend/resume ability'
  spec.homepage      = 'https://github.com/RnD-Soft/burst'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'activejob'
  spec.add_dependency 'activerecord'
  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
end
