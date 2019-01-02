# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "burst"
  spec.version       = "0.1.0"
  spec.authors       = ["Samoilenko Yuri"]
  spec.email         = ["kinnalru@gmail.com"]
  spec.summary       = "Jobs flow management on top of ActiveJob"
  spec.description   = "Parallel job runner witch handles dependency and results of jobs"
  spec.homepage      = "https://github.com/"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = "burst"
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "activejob"
  spec.add_dependency "activerecord"
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
end
