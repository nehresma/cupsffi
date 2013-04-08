# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "cupsffi/version"

Gem::Specification.new do |s|
  s.name        = "cupsffi"
  s.version     = Cupsffi::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Nathan Ehresman"]
  s.email       = ["nehresma@gmail.com"]
  s.homepage    = "https://github.com/nehresma/cupsffi"
  s.summary     = %q{FFI wrapper around libcups}
  s.description = %q{Simple wrapper around libcups to give CUPS printing capabilities to Ruby apps.}

  s.add_development_dependency "ffi"
  s.add_runtime_dependency "ffi"

  s.rubyforge_project = "cupsffi"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
