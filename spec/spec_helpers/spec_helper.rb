# Copyright 2001-2014 Rally Software Development Corp. All Rights Reserved.
require 'rspec'
require 'simplecov'

SimpleCov.start do
  add_filter "/spec/"
end

require 'date'
require 'time'
require 'nokogiri'
require 'securerandom'
require 'rallyeif-wrk'

module YetiTestUtils

  class << self
    def YetiTestUtils::load_xml(xml_string, connector_type = nil)
      # REXML::Document.new(xml_string)
      # Nokogiri::XML(xml_string)
      RallyEIF::WRK::XMLUtils.read_and_validate_config(xml_string, connector_type)
    end
  end

  def load_xml(xml_string, connector_type = nil)
    self.load_xml xml_string, connector_type
  end

  class OutputFile
    def initialize(file_name)
      @file_name = file_name
      @marker = File.size(file_name)
    end

    public
    def readlines
      f = File.new(@file_name)
      f.seek(@marker, IO::SEEK_CUR)
      f.readlines
    end
  end

  class << self
    def modify_config_data(config, section, new_tag, value, action, ref_tag)
      # given config which is a single string containing all of the '\n' separated lines for a config file,
      #       section which identifies the "major" section of the config where the augment is to take place
      #       new_tag with the name of the new tag which augments the config
      #       value with the content for aug_tag
      #       action -> one of 'before', 'after', 'replace', 'delete'
      #       ref_tag that identifies an existing tag in the target_section for reference
      # use regex to find and then modify the config with new_tag and value in the appropriate location
      # in the string relative to the ref_tag
      return config if config !~ /<#{section}>/

      secregex = Regexp.new(/(<#{section}>)(.*?)(<\/#{section}>).*?\n/m)
      sec_md = secregex.match(config)
      section_content = sec_md[2]

      reftag_regex = Regexp.new(/(<#{ref_tag}>.*?<\/#{ref_tag}>.*?\n)/m)
      tagmd = reftag_regex.match(section_content)
      ref_block = $1

      default_indent = " " * 16
      reftag_line = section_content.split("\n").find { |line| line =~ /<#{ref_tag}>/ }
      if reftag_line and reftag_line =~ /^(\s+)/
        indent = $1
      else
        indent = default_indent
      end

      augment = "<%s>%s</%s>" % [new_tag, value, new_tag]

      case action
        when "before"
          modified = section_content.sub(reftag_regex, "#{augment}\n#{indent}#{ref_block}")
        when "after"
          modified = section_content.sub(reftag_regex, "#{ref_block}#{indent}#{augment}\n")
        when "replace"
          modified = section_content.sub(reftag_regex, "#{augment}\n")
        when "delete"
          modified = section_content.sub(reftag_regex, "\n")
        else
          modified = section_content.dup
      end

      modified_section = [sec_md[1], modified, sec_md[3]].join("") + "\n"
      return config.sub(secregex, modified_section)
    end

    def create_test_and_steps(rally_connection, extra_fields = nil, num_steps = 3 )
      name = Time.now.strftime("%y%m%d%H%M%S") + Time.now.usec.to_s
      fields = {}
      fields[:Name] = name
      if !extra_fields.nil?
        fields.merge!(extra_fields)
      end
      testcase = rally_connection.create(fields)

      step_fields = {:TestCase => testcase, :Workspace => rally_connection.workspace}
      (1..num_steps).each do |step_num|
        step_fields[:Input] = "Input #{step_num}"
        step_fields[:ExpectedResult] = "Expected Result #{step_num}"
        rally_connection.rally.create(:testcasestep, step_fields)
      end
      testcase
    end

    def create_arbitrary_rally_artifact(rally_type, rally_connection, extra_fields = nil)
      name = Time.now.strftime("%y%m%d%H%M%S") + Time.now.usec.to_s
      fields = {}
      fields[:Name] = name
      if !extra_fields.nil?
        fields.merge!(extra_fields)
      end
      item = rally_connection.rally.create(rally_type,fields)
      return [item, fields[:Name]]
    end
    
    # create an object of the same type as the connection
    def create_rally_artifact(rally_connection, extra_fields = nil)
      name = Time.now.strftime("%y%m%d%H%M%S") + Time.now.usec.to_s
      fields = {}
      fields[:Name] = name
      if !extra_fields.nil?
        fields.merge!(extra_fields)
      end
      item = rally_connection.create(fields)
      return [item, fields[:Name]]
    end

    #def rally_connect(config_file)
    #  rally_connection = read_config(config_file)
    #  rally_connection.connect()
    #  return rally_connection
    #end

    def read_config(config_file)
      #root = XMLUtils::strip_empty_text_nodes(YetiTestUtils::load_xml(config_file).root)
      root = YetiTestUtils::load_xml(config_file).root
      RallyEIF::WRK::RallyConnection.new(root)
    end
  end

end
