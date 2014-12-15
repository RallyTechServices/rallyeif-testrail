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

#  sf_spec_helper.rb
#

include YetiTestUtils

module SalesForceSpecHelper

  TestRailConnection      = RallyEIF::WRK::TestRailConnection   if not defined?(TestRailConnection)
  RecoverableException    = RallyEIF::WRK::RecoverableException   if not defined?(RecoverableException)
  UnrecoverableException  = RallyEIF::WRK::UnrecoverableException if not defined?(UnrecoverableException)
  YetiSelector            = RallyEIF::WRK::YetiSelector           if not defined?(YetiSelector)
  FieldMap                = RallyEIF::WRK::FieldMap               if not defined?(FieldMap)
  Connector               = RallyEIF::WRK::Connector              if not defined?(Connector)
  
  SALESFORCE_STATIC_CONFIG = "
    <config>
      <SalesForceConnection>
        <Url>#{TestConfig::SF_URL}</Url>
        <User>#{TestConfig::SF_USER}</User>
        <Password>#{TestConfig::SF_PASSWORD}</Password>
        <ConsumerKey>#{TestConfig::SF_CONSUMERKEY}</ConsumerKey>
        <ConsumerSecret>#{TestConfig::SF_CONSUMERSECRET}</ConsumerSecret>
        <ExternalIDField>#{TestConfig::SF_EXTERNAL_ID_FIELD}</ExternalIDField>
        <ArtifactType>#{TestConfig::SF_ARTIFACT_TYPE}</ArtifactType>
      </SalesForceConnection>
    </config>"

  SALESFORCE_CONNECTOR_STANDARD_CONFIG = "
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
  
      <SalesForceConnection>
        <User>user@company.com</User>
        <Password>Secret</Password>
        <ExternalIDField>#{TestConfig::SF_EXTERNAL_ID_FIELD}</ExternalIDField>
        <ConsumerKey>#{TestConfig::SF_CONSUMERKEY}</ConsumerKey>
        <ConsumerSecret>#{TestConfig::SF_CONSUMERSECRET}</ConsumerSecret>
        <ArtifactType>#{TestConfig::SF_ARTIFACT_TYPE}</ArtifactType>
      </SalesForceConnection>

      <Connector>
        <FieldMapping>
          <Field><Rally>Name</Rally>   <Other>Headline</Other></Field>
          <Field><Rally>Project</Rally><Other>Project</Other></Field>
        </FieldMapping>
      </Connector>
    </config>"
  

      
  def salesforce_connect(config_file)
    root = YetiTestUtils::load_xml(config_file).root
    connection = SalesForceConnection.new(root)
    connection.connect()
    return connection
  end

  def rally_connect(config_file)
    root = YetiTestUtils::load_xml(config_file).root
    connection = RallyEIF::WRK::RallyConnection.new(root)
    connection.connect()
    return connection
  end
  
  def create_salesforce_artifact(connection, extra_fields = nil)
    connection.salesforce.materialize("User")
    current_user = User.find_by_username(connection.user)
    
    name = 'Time-' + Time.now.strftime("%Y%m%d%H%M%S") + '-' + Time.now.usec.to_s
    fields            = {}
    fields["Subject"] = name
    fields["OwnerId"] = current_user["Id"]
    fields["Origin"]  = "Web"
      
    # Code around bug in SF... whereby boolean fields require a value
    bools = connection.boolean_fields
    bools.each do |field|
      fields[field] = false
    end
      
    if !extra_fields.nil?
      fields.merge!(extra_fields)
    end
    item = connection.create(fields)
    return [item, fields['Subject']]
  end
  
end

class SFItem
  attr_accessor :Name
  
  def initialize(name=nil)
    if name.nil?
      @Name = "fred"
    else 
      @Name = name
    end
  end
  
end