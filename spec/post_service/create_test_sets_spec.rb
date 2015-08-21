# 
# The post service action "create_test_sets" is
# used in the TestCaseResult/TestResult connector.  After the test case results have
# been created, it will go and create test sets for each test run, 
# then associate the test case result with a test set.

# 
require File.dirname(__FILE__) + '/../spec_helpers/spec_helper'
require File.dirname(__FILE__) + '/../spec_helpers/testrail_spec_helper'

include TestRailSpecHelper
include YetiTestUtils

describe "When creating test sets for test case results" do
  
  before(:each) do
    
    # Make a "TestCase" connection.
    #    (already defined in TestRailSpecHelper::TESTRAIL_STORY_FIELD_TO_ASSOCIATE_PLAN_CONFIG)

    # Make a "TestResult" connection.
    config_testresult = YetiTestUtils::modify_config_data(
        TestRailSpecHelper::TESTRAIL_STORY_FIELD_TO_ASSOCIATE_PLAN_CONFIG, #1 CONFIG  - The config file to be augmented
        "TestRailConnection",                       #2 SECTION - XML element of CONFIG to be augmented
        "ArtifactType",                             #3 NEWTAG  - New tag name in reference to REFTAG
        'TestResult',                               #4 VALUE   - New value to put into NEWTAG
        "replace",                                  #5 ACTION  - [before, after, replace, delete]
        "ArtifactType")                             #6 REFTAG  - Existing tag in SECTION        

        # Make a "TestRun" connection.
    config_testrun = YetiTestUtils::modify_config_data(
        TestRailSpecHelper::TESTRAIL_STORY_FIELD_TO_ASSOCIATE_PLAN_CONFIG, #1 CONFIG  - The config file to be augmented
        "TestRailConnection",                       #2 SECTION - XML element of CONFIG to be augmented
        "ArtifactType",                             #3 NEWTAG  - New tag name in reference to REFTAG
        'TestRun',                                  #4 VALUE   - New value to put into NEWTAG
        "replace",                                  #5 ACTION  - [before, after, replace, delete]
        "ArtifactType")                             #6 REFTAG  - Existing tag in SECTION

    # Make a "TestPlan" connection.
    config_testplan = YetiTestUtils::modify_config_data(
        TestRailSpecHelper::TESTRAIL_STORY_FIELD_TO_ASSOCIATE_PLAN_CONFIG, #1 CONFIG  - The config file to be augmented
        "TestRailConnection",                       #2 SECTION - XML element of CONFIG to be augmented
        "ArtifactType",                             #3 NEWTAG  - New tag name in reference to REFTAG
        'TestPlan',                                 #4 VALUE   - New value to put into NEWTAG
        "replace",                                  #5 ACTION  - [before, after, replace, delete]
        "ArtifactType")                             #6 REFTAG  - Existing tag in SECTION
    
    # Make a "TestSuite" connection.
    config_testsuite = YetiTestUtils::modify_config_data(
        TestRailSpecHelper::TESTRAIL_STORY_FIELD_TO_ASSOCIATE_PLAN_CONFIG, #1 CONFIG  - The config file to be augmented
        "TestRailConnection",                       #2 SECTION - XML element of CONFIG to be augmented
        "ArtifactType",                             #3 NEWTAG  - New tag name in reference to REFTAG
        'TestSuite',                                #4 VALUE   - New value to put into NEWTAG
        "replace",                                  #5 ACTION  - [before, after, replace, delete]
        "ArtifactType")                             #6 REFTAG  - Existing tag in SECTION

    # Make a "TestSection" connection.
    config_testsection = YetiTestUtils::modify_config_data(
        TestRailSpecHelper::TESTRAIL_STORY_FIELD_TO_ASSOCIATE_PLAN_CONFIG, #1 CONFIG  - The config file to be augmented
        "TestRailConnection",                       #2 SECTION - XML element of CONFIG to be augmented
        "ArtifactType",                             #3 NEWTAG  - New tag name in reference to REFTAG
        'TestSection',                              #4 VALUE   - New value to put into NEWTAG
        "replace",                                  #5 ACTION  - [before, after, replace, delete]
        "ArtifactType")                             #6 REFTAG  - Existing tag in SECTION    
    
    # Make a 19-digit (somewhat) random number because:
    # - we want it to be 19 digits always (not 18 sometimes)
    # - 19 is less than 2^64 (our OID limitation)
    micro_secs = sprintf('%07d', Time.now.usec)[-5..-1]
    @unique_number = Time.now.strftime("%Y%m%d%H%M%S") + micro_secs
    
    @connection_testcase    = testrail_connect(TestRailSpecHelper::TESTRAIL_STORY_FIELD_TO_ASSOCIATE_PLAN_CONFIG)
    @connection_testresult  = testrail_connect(config_testresult)    
    @connection_testrun     = testrail_connect(config_testrun)
    @connection_testplan    = testrail_connect(config_testplan)
    @connection_testsuite   = testrail_connect(config_testsuite)
    @connection_testsection = testrail_connect(config_testsection)
    
    @items_to_remove_testcase     = []
    @items_to_remove_testresult   = []
    @items_to_remove_testrun      = []
    @items_to_remove_testplan     = []
    @items_to_remove_testsuite    = []
    @items_to_remove_testsection  = []

    @rally_connection = YetiTestUtils::rally_tr_connect(TestRailSpecHelper::RALLY_HIERARCHICAL_CONFIG)
    @items_to_remove_rally = []
  end
  
  after(:each) do    
    @items_to_remove_testcase.each   { |item| @connection_testcase.delete(item)   } 
    @items_to_remove_testresult.each { |item| @connection_testresult.delete(item) }
    @items_to_remove_testrun.each    { |item| @connection_testrun.delete(item)    }
    @items_to_remove_testplan.each   { |item| @connection_testplan.delete(item)   }
    @items_to_remove_testsuite.each  { |item| @connection_testsuite.delete(item)  }
    @items_to_remove_testsection.each{ |item| @connection_testsection.delete(item)}
      
    @items_to_remove_rally.each do |item|
      YetiTestUtils::rally_delete(item)
    end
  end
  
#  it "should create a test set for each test run" do
#    # TODO
#  end
#  
#  it "should not create a test set if the test run already has a corresponding test set" do
#    # TODO
#    
#  end
#  
  it "(1), should put the test set into the same project as a story that is linked to the test run's test plan" do
    # 1 - Create a TestSuite
    suite,suite_id = create_testrail_artifact(@connection_testsuite, nil)
    @items_to_remove_testsuite.push(suite)

    # 2 - Create a TestSection
    extra_fields = {'suite_id' => suite_id}
    section,section_id = create_testrail_artifact(@connection_testsection, extra_fields)
    @items_to_remove_testsection.push(section)

    # 3 - Create a Testcase
    extra_fields = {'section_id' => section_id}
    testcase,testcase_id = create_testrail_artifact(@connection_testcase, extra_fields)
    @items_to_remove_testcase.push(testcase)

    # 4 - Create a TestPlan with a TestRun for the above TestCase
    extra_fields = {'entries' => [{ 'suite_id'    => suite_id,
                                    'include_all' => false,
                                    'case_ids'    => [testcase_id],
                                    'runs'        => [{'include_all' => true}]
                                 }]
    }
    testplan,testplan_id = create_testrail_artifact(@connection_testplan, extra_fields)
    @items_to_remove_testplan.push(testplan)
    run_id = testplan['entries'][0]['runs'][0]['id']
    
    # 5 - Create a Rally UserStory with the child project with a TestPlan ID
    story_fields = { 
      'Project' => TestConfig::RALLY_PROJECT_HIERARCHICAL_CHILD_OID, # a child project
      TestConfig::TR_RALLY_FIELD_TO_HOLD_PLAN_ID => testplan_id      # associate story with plan
    }
    rally_story, rally_story_name = YetiTestUtils::create_arbitrary_rally_artifact('HierarchicalRequirement',@rally_connection, story_fields)
    @items_to_remove_rally.push(rally_story)

    # 6 - Create a test set in Rally
    @service_action = RallyEIF::WRK::PostServiceActions::CreateTestSets.new()
    @service_action.setup('', @rally_connection, @connection_testresult)
    @service_action.perform_post_service_action(:copy_to_rally,[])
    
    created_test_set = @service_action.find_rally_test_set_by_name("#{run_id}:")
    expect(created_test_set).to_not be_nil
    expect(created_test_set.Project.ObjectID).to eq(TestConfig::RALLY_PROJECT_HIERARCHICAL_CHILD_OID)
        
  end
  
  it "(2), should put the test set into the same iteration as a story that is linked to the test run's test plan" do
    # 1 - Create a TestSuite
    suite,suite_id = create_testrail_artifact(@connection_testsuite, nil)
    @items_to_remove_testsuite.push(suite)

    # 2 - Create a TestSection
    extra_fields = {'suite_id' => suite_id}
    section,section_id = create_testrail_artifact(@connection_testsection, extra_fields)
    @items_to_remove_testsection.push(section)

    # 3 - Create a Testcase
    extra_fields = {'section_id' => section_id}
    testcase,testcase_id = create_testrail_artifact(@connection_testcase, extra_fields)
    @items_to_remove_testcase.push(testcase)

    # 4 - Create a TestPlan with a TestRun for the above TestCase
    extra_fields = {'entries' => [{ 'suite_id'    => suite_id,
                                    'include_all' => false,
                                    'case_ids'    => [testcase_id],
                                    'runs'        => [{'include_all' => true}]
                                 }]
    }
    testplan,testplan_id = create_testrail_artifact(@connection_testplan, extra_fields)
    @items_to_remove_testplan.push(testplan)
    run_id = testplan['entries'][0]['runs'][0]['id']

    # 5 - Create a Rally Iteration
    iteration_fields = {
      'StartDate' => '2015-05-10',
      'EndDate'   => '2015-05-11',
      'State'     => 'Planning'
    }
    rally_iteration, rally_iteration_name = YetiTestUtils::create_arbitrary_rally_artifact('Iteration',@rally_connection, iteration_fields)
    @items_to_remove_rally.push(rally_iteration)
    
    # 6 - Create a Rally UserStory in the new Iteration with a TestPlan ID
    story_fields = {
      'Iteration' => rally_iteration,
      TestConfig::TR_RALLY_FIELD_TO_HOLD_PLAN_ID => testplan_id #associate story with plan
    }
    rally_story, rally_story_name = YetiTestUtils::create_arbitrary_rally_artifact('HierarchicalRequirement',@rally_connection, story_fields)
    @items_to_remove_rally.push(rally_story)

    # 7 - Perform the POST_SERVICE_ACTION...
    @service_action = RallyEIF::WRK::PostServiceActions::CreateTestSets.new()
    @service_action.setup('', @rally_connection, @connection_testresult)
    @service_action.perform_post_service_action(:copy_to_rally,[])

    # 8 - Try to find the Rally TestSet
    created_test_set = @service_action.find_rally_test_set_by_name("#{run_id}:")
    
    # 9 - It should exist
    expect(created_test_set).to_not be_nil
    
    # 10 - The new Rally TestSet should be in the same iteration as the story
    expect(created_test_set.Iteration.ObjectID).to eq(rally_iteration.ObjectID)
    
  end
  
# Removed for now (20-Aug-2015) becuase customer decided they did
# not want to copy test sets if the test run’s test plan id isn’t in a story
#  it "(3), should put the test set into the default project if there is not a story linked to the test run's test plan" do
#    # 1 - Create a TestSuite
#    suite,suite_id = create_testrail_artifact(@connection_testsuite, nil)
#    @items_to_remove_testsuite.push(suite)
#
#    # 2 - Create a TestSection
#    extra_fields = {'suite_id' => suite_id}
#    section,section_id = create_testrail_artifact(@connection_testsection, extra_fields)
#    @items_to_remove_testsection.push(section)
#
#    # 3 - Create a Testcase
#    extra_fields = {'section_id' => section_id}
#    testcase,testcase_id = create_testrail_artifact(@connection_testcase, extra_fields)
#    @items_to_remove_testcase.push(testcase)
#    
#    # 4 - Create a TestPlan with a TestRun for the above TestCase
#    extra_fields =  {'entries' => [{  'suite_id'    => suite_id,
#                                      'include_all' => false,
#                                      'case_ids'    => [testcase_id],
#                                      'runs'        => [{'include_all' => true}]
#                                  }]
#    }
#    testplan,testplan_id = create_testrail_artifact(@connection_testplan, extra_fields)
#    @items_to_remove_testplan.push(testplan)
#    run_id = testplan['entries'][0]['runs'][0]['id']
#    
#    # 5 -
#    @service_action = RallyEIF::WRK::PostServiceActions::CreateTestSets.new()
#    @service_action.setup('', @rally_connection, @connection_testresult)
#    @service_action.perform_post_service_action(:copy_to_rally,[])
#
#    # 6 -
#    created_test_set = @service_action.find_rally_test_set_by_name("#{run_id}:") 
#    expect(created_test_set).to_not be_nil
#    expect(created_test_set.Project.ObjectID).to eq(TestConfig::RALLY_PROJECT_HIERARCHICAL_PARENT_OID)
#    
#  end
end