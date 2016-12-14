# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'midian/version'

Gem::Specification.new do |spec|
  spec.name          = "midian"
  spec.version       = Midian::VERSION
  spec.authors       = ["Roger Jungemann"]
  spec.email         = ["roger@thefifthcircuit.com"]

  spec.summary       = %q{Extended MML compiler}
  spec.homepage      = "https://github.com/rjungemann/midian"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'colorize', '~> 0.7.4'
  spec.add_dependency 'parslet', '~> 1.7.1'
  spec.add_development_dependency "bundler", "~> 1.13"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
