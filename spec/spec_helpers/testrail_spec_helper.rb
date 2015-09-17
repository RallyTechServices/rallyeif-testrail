# Copyright 2001-2015 Rally Software Development Corp. All Rights Reserved.
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
        <RunDaysToSearch>14</RunDaysToSearch>
      </TestRailConnection>
    </config>"

  TESTRAIL_STORY_FIELD_TO_ASSOCIATE_PLAN_CONFIG = "
    <config>
      <TestRailConnection>
        <Url>#{TestConfig::TR_URL}</Url>
        <User>#{TestConfig::TR_USER}</User>
        <Password>#{TestConfig::TR_PASSWORD}</Password>
        <ExternalIDField>#{TestConfig::TR_EXTERNAL_ID_FIELD}</ExternalIDField>
        <ArtifactType>#{TestConfig::TR_ARTIFACT_TYPE}</ArtifactType>
        <Project>#{TestConfig::TR_PROJECT}</Project>
        <RallyStoryFieldForPlanID>#{TestConfig::TR_RALLY_FIELD_TO_HOLD_PLAN_ID}</RallyStoryFieldForPlanID>
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
  
  RALLY_HIERARCHICAL_CONFIG = "
  <config>
    <RallyTestResultConnection>
        <Url>#{TestConfig::RALLY_URL}</Url>
        <WorkspaceName>#{TestConfig::RALLY_WORKSPACE}</WorkspaceName>
        <Projects>
            <Project>#{TestConfig::RALLY_PROJECT_HIERARCHICAL_PARENT}</Project>
        </Projects>
        <User>#{TestConfig::RALLY_USER}</User>
        <Password>#{TestConfig::RALLY_PASSWORD}</Password>
        <ArtifactType>TestCaseResult</ArtifactType>
    </RallyTestResultConnection>
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
    current_artifact = connection.artifact_type.to_s.downcase
    case current_artifact
    when 'testcase'
      # TestCase system fields (* = system fields supported on POST):
      #     created_by        int        The ID of the user who created the test case
      #     created_on        timestamp  The date/time when the test case was created (as UNIX timestamp)
      #  *  estimate          timespan   The estimate, e.g. "30s" or "1m 45s"
      #     estimate_forecast timespan   The estimate forecast, e.g. "30s" or "1m 45s"
      #     id                int        The unique ID of the test case
      #  *  milestone_id      int        The ID of the milestone that is linked to the test case
      #  *  priority_id       int        The ID of the priority that is linked to the test case
      #  *  refs              string     A comma-separated list of references/requirements
      #     section_id        int        The ID of the section the test case belongs to
      #     suite_id          int        The ID of the suite the test case belongs to
      #  *  title             string     The title of the test case
      #  *  type_id           int        The ID of the test case type that is linked to the test case
      #     updated_by        int        The ID of the user who last updated the test case
      #     updated_on        timestamp  The date/time when the test case was last updated (as UNIX timestamp)
      
      fields = {'estimate'      => '3m14s',
                'priority_id'   => 5,
                'refs'          => '',
                'title'         => 'Spec TestCase' + title,
                'type_id'       => 6}
      fields.merge!(extra_fields) if !extra_fields.nil?
      item = connection.create(fields)
      return [item, item['id']]

    when 'testrun'
      # TestRun system fields (* = system fields supported on POST):
      #  *  assignedto_id   int        The ID of the user the entire test run is assigned to
      #     blocked_count   int        The amount of tests in the test run marked as blocked
      #  *  case_ids        array      An array of case IDs for the custom case selection ????
      #     completed_on    timestamp  The date/time when the test run was closed (as UNIX timestamp)
      #     config          string     The configuration of the test run as string (if part of a test plan)
      #     config_ids      array      The array of IDs of the configurations of the test run (if part of a test plan)
      #     created_by      int        The ID of the user who created the test run
      #     created_on      timestamp  The date/time when the test run was created (as UNIX timestamp)
      #     custom_status?  int        The amount of tests in the test run with the respective custom status
      #         _count          ????
      #  *  description     string     The description of the test run
      #     failed_count    int        The amount of tests in the test run marked as failed
      #     id              int        The unique ID of the test run
      #  *  include_all     bool       True if the test run includes all test cases and false otherwise
      #     is_completed    bool       True if the test run was closed and false otherwise
      #  *  milestone_id    int        The ID of the milestone this test run belongs to
      #     plan_id         int        The ID of the test plan this test run belongs to
      #  *  name            string     The name of the test run
      #     passed_count    int        The amount of tests in the test run marked as passed
      #     project_id      int        The ID of the project this test run belongs to
      #     retest_count    int        The amount of tests in the test run marked as retest
      #  *  suite_id        int        The ID of the test suite this test run is derived from
      #     untested_count  int        The amount of tests in the test run marked as untested
      #     url             string     The address/URL of the test run in the user interface
      fields = {'assignedto_id' => 1                      ,
                'case_ids'      => [2]                    ,
                'description'   => 'desc'                 ,
                'include_all'   => false                  ,
                'suite_id'      => 1                      ,
                #'milestone_id'  => 1                      ,
                'name'          => 'Spec TestRun - ' + title  }
      fields.merge!(extra_fields) if !extra_fields.nil?
      item = connection.create(fields)
      return [item, item['id']]

    when 'testresult'
      # TestResult system fields (* = system fields supported on POST):
      #  *  assignedto_id  int        The ID of the assignee (user) of the test result
      #  *  comment        string     The comment or error message of the test result
      #     created_by     int        The ID of the user who created the test result
      #     created_on     timestamp  The date/time when the test result was created (as UNIX timestamp)
      #  *  defects        string     A comma-separated list of defects linked to the test result
      #  *  elapsed        timespan   The amount of time it took to execute the test (e.g. "1m" or "2m 30s")
      #     id             int        The unique ID of the test result
      #  *  status_id      int        The status of the test result, e.g. passed or failed, also see get_statuses
      #                               1=Passed, 2=Blocked, 3=Untested, 4=Retest, 5=Failed
      #     test_id        int        The ID of the test this test result belongs to
      #  *  version        string     The (build) version the test was executed against
      #
      # Required in a 'GET' url:
      #     get_results:            :test_id
      #     get_results_for_case:   :run_id,  :case_id
      #     get_results_for_run:    :run_id
      #
      # Require in a 'POST' url:
      #     add_result:             :test_id
      #     add_result_for_case:    :run_id,  :case_id
      #     add_results:            :run_id
      #     add_results_for_cases:  :run_id
      fields = {'assignedto_id' => 1,
                'comment'       => 'Spec TestResult - ' + title,
                'defects'       => 'TR-7'               ,
                'elapsed'       => '15s'                ,
                'status_id'     => 5                    ,
                'version'       => '1.0 RC1 build 3724' }
      fields.merge!(extra_fields) if !extra_fields.nil?
      
      item = connection.create(fields)
      return [item, item['id']]
        
    when 'testplan'
      # TestPlan system fields (* = system fields supported on POST):
      #     assignedto_id   int       The ID of the user the entire test plan is assigned to
      #     blocked_count   int       The amount of tests in the test plan marked as blocked
      #     completed_on    timestamp The date/time when the test plan was closed (as UNIX timestamp)
      #     created_by      int       The ID of the user who created the test plan
      #     created_on      timestamp The date/time when the test plan was created (as UNIX timestamp)
      #     custom_status?_count int  The amount of tests in the test plan with the respective custom status
      #  *  description     string    The description of the test plan
      #  *  entries         array     An array of 'entries', i.e. group of test runs
      #     failed_count    int       The amount of tests in the test plan marked as failed
      #     id              int       The unique ID of the test plan
      #     is_completed    bool      True if the test plan was closed and false otherwise
      #  *  milestone_id    int       The ID of the milestone this test plan belongs to
      #  *  name            string    The name of the test plan
      #     passed_count    int       The amount of tests in the test plan marked as passed
      #     project_id      int       The ID of the project this test plan belongs to
      #     retest_count    int       The amount of tests in the test plan marked as retest
      #     untested_count  int       The amount of tests in the test plan marked as untested
      #     url             string    The address/URL of the test plan in the user interface
      fields = {  'name'          => 'Spec TestPlan - ' + title,
                  'description'   => '',
                  'milestone_id'  => nil,
                  'entries'       => []}
      fields.merge!(extra_fields) if !extra_fields.nil?
      item = connection.create(fields)
      return [item, item['id']]

    when 'testsuite'
      fields = {  'name'        => 'Spec TestSuite - ' + title,
                  'description' => 'description for Spec TestSuite' }
      fields.merge!(extra_fields) if !extra_fields.nil?
      item = connection.create(fields)
        # Returns:
        #       {"id"=>97,
        #        "name"=>"Suite '1' of '5'",
        #        "description"=>"One of JPKole's test suites.",
        #        "project_id"=>55,
        #        "is_master"=>false,
        #        "is_baseline"=>false,
        #        "is_completed"=>false,
        #        "completed_on"=>nil,
        #        "url"=>"https://tsrally.testrail.com/index.php?/suites/view/97"}
      return [item, item['id']]

    when 'testsection'
      fields = {  'description' => 'description for Spec TestSection',
                  'suite_id'    => 0,
                  'prent_id'    => nil,
                  'name'        => 'Spec TestSection - ' + title
               }
      fields.merge!(extra_fields) if !extra_fields.nil?
      item = connection.create(fields)
      return [item, item['id']]

    else
      raise UnrecoverableException.new("Unrecognized value for <ArtifactType> '#{connection.artifact_type}' (msgA)", self)
    end
    return nil
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