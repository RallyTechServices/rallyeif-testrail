# Copyright 2001-2014 Rally Software Development Corp. All Rights Reserved.
require File.dirname(__FILE__) + '/spec_helper'
if !File.exist?(File.dirname(__FILE__) + '/test_configuration_helper.rb')
  puts
  puts " You must create a file with your test values at #{File.dirname(__FILE__)}/test_configuration_helper.rb"
  exit 1
end
require File.dirname(__FILE__) + '/test_configuration_helper'
require 'rallyeif-wrk'
require File.dirname(__FILE__) + '/../../lib/rallyeif-testrail'

#  testrail_spec_helper.rb
#

include YetiTestUtils

module TestRailSpecHelper

  TestRailConnection      = RallyEIF::WRK::TestRailConnection     if not defined?(TestRailConnection)
  RecoverableException    = RallyEIF::WRK::RecoverableException   if not defined?(RecoverableException)
  UnrecoverableException  = RallyEIF::WRK::UnrecoverableException if not defined?(UnrecoverableException)
  YetiSelector            = RallyEIF::WRK::YetiSelector           if not defined?(YetiSelector)
  FieldMap                = RallyEIF::WRK::FieldMap               if not defined?(FieldMap)
  Connector               = RallyEIF::WRK::Connector              if not defined?(Connector)
  
  TESTRAIL_STATIC_CONFIG = "
    <config>
      <TestRailConnection>
        <Url>#{TestConfig::TR_URL}</Url>
        <User>#{TestConfig::TR_USER}</User>
        <Password>#{TestConfig::TR_PASSWORD}</Password>
        <ExternalIDField>#{TestConfig::TR_EXTERNAL_ID_FIELD}</ExternalIDField>
        <ArtifactType>#{TestConfig::TR_ARTIFACT_TYPE}</ArtifactType>
        <Project>#{TestConfig::TR_PROJECT}</Project>
      </TestRailConnection>
    </config>"

  TESTRAIL_MISSING_ARTIFACT_CONFIG = "
    <config>
      <TestRailConnection>
        <Url>#{TestConfig::TR_URL}</Url>
        <User>#{TestConfig::TR_USER}</User>
        <Password>#{TestConfig::TR_PASSWORD}</Password>
        <ExternalIDField>#{TestConfig::TR_EXTERNAL_ID_FIELD}</ExternalIDField>
        <!-- And no ArtifactType -->
        <Project>#{TestConfig::TR_PROJECT}</Project>
      </TestRailConnection>
    </config>"

    TESTRAIL_MISSING_PROJECT_CONFIG = "
    <config>
      <TestRailConnection>
        <Url>#{TestConfig::TR_URL}</Url>
        <User>#{TestConfig::TR_USER}</User>
        <Password>#{TestConfig::TR_PASSWORD}</Password>
        <ExternalIDField>#{TestConfig::TR_EXTERNAL_ID_FIELD}</ExternalIDField>
        <ArtifactType>#{TestConfig::TR_ARTIFACT_TYPE}</ArtifactType>
        <!-- And no Project -->
      </TestRailConnection>
    </config>"

    TESTRAIL_MISSING_URL_CONFIG = "
    <config>
      <TestRailConnection>
        <!-- And no Url -->
        <User>#{TestConfig::TR_USER}</User>
        <Password>#{TestConfig::TR_PASSWORD}</Password>
        <ExternalIDField>#{TestConfig::TR_EXTERNAL_ID_FIELD}</ExternalIDField>
        <ArtifactType>#{TestConfig::TR_ARTIFACT_TYPE}</ArtifactType>
        <Project>#{TestConfig::TR_PROJECT}</Project>
      </TestRailConnection>
    </config>"
    
  TESTRAIL_CONNECTOR_STANDARD_CONFIG = "
    <config>
      <RallyConnection>
        <Url>#{TestConfig::RALLY_URL}</Url>
        <WorkspaceName>#{TestConfig::RALLY_WORKSPACE}</WorkspaceName>
        <Projects>
          <Project>#{TestConfig::RALLY_PROJECT_1}</Project>
        </Projects>
        <User>#{TestConfig::RALLY_USER}</User>
        <Password>#{TestConfig::RALLY_PASSWORD}</Password>
        <ArtifactType>Defect</ArtifactType>
        <ExternalIDField>#{TestConfig::RALLY_EXTERNAL_ID_FIELD}</ExternalIDField>
      </RallyConnection>
  
      <TestRailConnection>
        <User>user@company.com</User>
        <Password>Secret</Password>
        <ExternalIDField>#{TestConfig::TR_EXTERNAL_ID_FIELD}</ExternalIDField>
        <ArtifactType>#{TestConfig::TR_ARTIFACT_TYPE}</ArtifactType>
      </TestRailConnection>

      <Connector>
        <FieldMapping>
          <Field><Rally>Name</Rally>   <Other>Headline</Other></Field>
          <Field><Rally>Project</Rally><Other>Project</Other></Field>
        </FieldMapping>
      </Connector>
    </config>"

  TESTRAIL_EXTERNAL_FIELDS_CONFIG = "
    <config>
      <TestRailConnection>
        <Url>#{TestConfig::TR_URL}</Url>
        <User>#{TestConfig::TR_USER}</User>
        <Password>#{TestConfig::TR_PASSWORD}</Password>
        <IDField>#{TestConfig::TR_ID_FIELD}</IDField>
        <ExternalIDField>#{TestConfig::TR_EXTERNAL_ID_FIELD}</ExternalIDField>
        <ExternalEndUserIDField>#{TestConfig::TR_EXTERNAL_EU_ID_FIELD}</ExternalEndUserIDField>
        <CrosslinkUrlField>#{TestConfig::TR_CROSSLINK_FIELD}</CrosslinkUrlField>
        <ArtifactType>#{TestConfig::TR_ARTIFACT_TYPE}</ArtifactType>
        <Project>#{TestConfig::TR_PROJECT}</Project>
      </TestRailConnection>
    </config>"
      
  def testrail_connect(config_file)
    root = YetiTestUtils::load_xml(config_file).root
    connection = TestRailConnection.new(root)
    connection.connect()
    return connection
  end

  def rally_connect(config_file)
    root = YetiTestUtils::load_xml(config_file).root
    connection = RallyEIF::WRK::RallyConnection.new(root)
    connection.connect()
    return connection
  end
  
  # Creates a TestRail Artifact
  # @arg1 connection - TestRail connection packet
  # @arg2 extra_fields (optional) to be added to new object
  # @ret1 item - the new TestRail object created
  # @ret2 title - the 'title' field of the new object
  #
  def create_testrail_artifact(connection, extra_fields = nil)
    
    # Generate a title like "Time-2015-01-06_12:04:12-965143"
    title = 'Time-' + Time.now.strftime("%Y-%m-%d_%H:%M:%S") + '-' + Time.now.usec.to_s

    case TestConfig::TR_ARTIFACT_TYPE.downcase
    when 'testcase'
      # title        string   The title of the test case (required)
      # type_id      int      The ID of the case type
      #                          1 Automated
      #                          2 Functionality
      #                          3 Performance
      #                          4 Regression
      #                          5 Usability
      #                          6 Other
      # priority_id  int      The ID of the case priority
      # estimate     timespan The estimate, e.g. "30s" or "1m 45s"
      # milestone_id int      The ID of the milestone to link to the test case
      # refs         string   A comma-separated list of references/requirements
      fields = {'title'         => title    ,
                'type_id'       => 6        ,
                'priority_id'   => 5        ,
                'estimate'      => '3m14s'  ,
                'milestone_id'  => 1        ,
                'refs'          => ''       }
    else
      raise UnrecoverableException.new("Unrecognize value for TR_ARTIFACT_TYPE ('#{TestConfig::TR_ARTIFACT_TYPE.downcase}')", self)
    end

    if !extra_fields.nil?
      fields.merge!(extra_fields)
    end
    item = connection.create(fields)
    return [item, fields['title']]
  end
  
end

class TRItem
  attr_accessor :Name
  
  def initialize(name=nil)
    if name.nil?
      @Name = "fred"
    else 
      @Name = name
    end
  end
  
end