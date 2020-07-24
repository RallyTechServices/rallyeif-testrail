#
# Gemspec for 'rallyeif-testrail-x.x.x.gem'
#

$LOAD_PATH << File.join(File.expand_path(File.dirname(__FILE__)), 'lib')
require 'rallyeif/testrail/version'

Gem::Specification.new do |spec|
  spec.name          = "rallyeif-testrail"
  spec.version       = RallyEIF::TestRail::Version
  spec.authors       = ["Rally Software Development Corp"]
  spec.email         = ["technical-services@rallydev.com"]
  spec.description   = %q{TestRail Spoke for EIF connectors}
  spec.summary       = %q{TestRail spoke for use with Hub of EIF}
  spec.homepage      = "https://github.com/RallyTechServices/rallyeif-testrail"
  spec.license       = "MIT"

  all_files          = `git ls-files`.split($/)
  spec.executables   = all_files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.files         = []
  exclusions         = %w(spec test features coverage pkg .gitignore Rakefile)
  spec.files         = all_files.reject{|fn| fn =~ /^(#{exclusions.join("|")})/}
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "rallyeif-wrk",       "= 0.5.5"

  spec.add_development_dependency "bundler",        "= 1.5.1"
  spec.add_development_dependency "rake",           "= 10.1.0"
  spec.add_development_dependency "rspec",          "= 2.14.0"
  #spec.add_development_dependency "simplecov",      "= 0.7.1"
end
