#
# Gemspec for 'rallyeif-sf-x.x.x.gem'
#

$LOAD_PATH << File.join(File.expand_path(File.dirname(__FILE__)), 'lib')
require 'rallyeif/salesforce/version'

Gem::Specification.new do |spec|
  spec.name          = "rallyeif-sf"
  spec.version       = RallyEIF::SalesForce::Version
  spec.authors       = ["Rally Software Development Corp"]
  spec.email         = ["technical-services@rallydev.com"]
  spec.description   = %q{SalesForce Spoke for EIF connectors}
  spec.summary       = %q{SalesForce spoke for use with Hub of EIF}
  spec.homepage      = "https://github.com/RallyTechServices/rallyeif-salesforce"
  spec.license       = "MIT"

  all_files          = `git ls-files`.split($/)
  spec.executables   = all_files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.files         = []
  exclusions         = %w(spec test features coverage pkg .gitignore Rakefile)
  spec.files         = all_files.reject{|fn| fn =~ /^(#{exclusions.join("|")})/}
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "rallyeif-wrk",       "= 0.5.4"
  spec.add_runtime_dependency "xml-simple",         "= 1.1.2"
  spec.add_runtime_dependency "mime-types",         "= 2.0"
  spec.add_runtime_dependency "databasedotcom",     "= 1.3.2"

  spec.add_development_dependency "activesupport",  "= 4.1.6"
  spec.add_development_dependency "bundler",        "= 1.5.1"
  spec.add_development_dependency "rake",           "= 10.1.0"
  spec.add_development_dependency "rspec",          "= 2.14.0"
  spec.add_development_dependency "simplecov",      "= 0.7.1"
  spec.add_development_dependency "ci_reporter",    "= 1.9.0"
  spec.add_development_dependency "geminabox",      "= 0.10.7"

end
