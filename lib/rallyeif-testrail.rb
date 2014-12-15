# Copyright 2001-2014 Rally Software Development Corp. All Rights Reserved.
min_version = "1.9.2"
if RUBY_VERSION < min_version
  abort "\nRally eif does not work with Ruby versions below #{min_version}.  Please upgrade.\n"
end

path_name = File.join(File.dirname(__FILE__), "rallyeif/**/*.rb")
file_names = Dir.glob(path_name)
file_names.each do |ruby_file|
  require ruby_file
end

module RallyEIF
  module WRK
  end
end