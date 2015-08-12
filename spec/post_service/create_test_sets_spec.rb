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
    
    # Make a "TestRun" connection.
    config_testrun = YetiTestUtils::modify_config_data(
        TestRailSpecHelper::TESTRAIL_STORY_FIELD_TO_ASSOCIATE_PLAN_CONFIG, #1 CONFIG  - The config file to be augmented
        "TestRailConnection",                       #2 SECTION - XML element of CONFIG to be augmented
        "ArtifactType",                             #3 NEWTAG  - New tag name in reference to REFTAG
        'TestRun',                                  #4 VALUE   - New value to put into NEWTAG
        "replace",                                  #5 ACTION  - [before, after, replace, delete]
        "ArtifactType")                             #6 REFTAG  - Existing tag in SECTION

    # Make a "Test Plan" connection.
    config_testplan = YetiTestUtils::modify_config_data(
        TestRailSpecHelper::TESTRAIL_STORY_FIELD_TO_ASSOCIATE_PLAN_CONFIG, #1 CONFIG  - The config file to be augmented
        "TestRailConnection",                       #2 SECTION - XML element of CONFIG to be augmented
        "ArtifactType",                             #3 NEWTAG  - New tag name in reference to REFTAG
        'TestPlan',                                 #4 VALUE   - New value to put into NEWTAG
        "replace",                                  #5 ACTION  - [before, after, replace, delete]
        "ArtifactType")                             #6 REFTAG  - Existing tag in SECTION
    
    # Make a "Test Suite" connection.
    config_testsuite = YetiTestUtils::modify_config_data(
        TestRailSpecHelper::TESTRAIL_STORY_FIELD_TO_ASSOCIATE_PLAN_CONFIG, #1 CONFIG  - The config file to be augmented
        "TestRailConnection",                       #2 SECTION - XML element of CONFIG to be augmented
        "ArtifactType",                             #3 NEWTAG  - New tag name in reference to REFTAG
        'TestSuite',                                #4 VALUE   - New value to put into NEWTAG
        "replace",                                  #5 ACTION  - [before, after, replace, delete]
        "ArtifactType")                             #6 REFTAG  - Existing tag in SECTION

    # Make a "Test Section" connection.
    config_testsection = YetiTestUtils::modify_config_data(
        TestRailSpecHelper::TESTRAIL_STORY_FIELD_TO_ASSOCIATE_PLAN_CONFIG, #1 CONFIG  - The config file to be augmented
        "TestRailConnection",                       #2 SECTION - XML element of CONFIG to be augmented
        "ArtifactType",                             #3 NEWTAG  - New tag name in reference to REFTAG
        'TestSection',                              #4 VALUE   - New value to put into NEWTAG
        "replace",                                  #5 ACTION  - [before, after, replace, delete]
        "ArtifactType")                             #6 REFTAG  - Existing tag in SECTION    

    # Make a "Test Section" connection.
    config_testresult = YetiTestUtils::modify_config_data(
        TestRailSpecHelper::TESTRAIL_STORY_FIELD_TO_ASSOCIATE_PLAN_CONFIG, #1 CONFIG  - The config file to be augmented
        "TestRailConnection",                       #2 SECTION - XML element of CONFIG to be augmented
        "ArtifactType",                             #3 NEWTAG  - New tag name in reference to REFTAG
        'TestResult',                               #4 VALUE   - New value to put into NEWTAG
        "replace",                                  #5 ACTION  - [before, after, replace, delete]
        "ArtifactType")                             #6 REFTAG  - Existing tag in SECTION    
        
    @unique_number = Time.now.strftime("%Y%m%d%H%M%S") + Time.now.usec.to_s
    
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
  it "should put the test set into the same project as a story that is linked to the test run's test plan" do
    suite,suite_id = create_testrail_artifact(@connection_testsuite, nil)
        @items_to_remove_testsuite.push(suite)
    
        extra_fields = {'suite_id' => suite_id}
        section,section_id = create_testrail_artifact(@connection_testsection, extra_fields)
        @items_to_remove_testsection.push(section)
    
        extra_fields = {'section_id' => section_id}
        testcase,testcase_id = create_testrail_artifact(@connection_testcase, extra_fields)
        @connection_testcase.update_external_id_fields(testcase, @unique_number , nil, nil)
        @items_to_remove_testcase.push(testcase)
        
        extra_fields =  {'entries' => [{  'suite_id'    => suite_id,
                          'include_all' => false,
                          'case_ids'    => [testcase_id],
                          'runs'        => [{  'include_all' => false, # Override selection
                                                'case_ids'   => [testcase_id]
                                           }]
                      }]
        }
        testplan,testplan_id = create_testrail_artifact(@connection_testplan, extra_fields)
        @items_to_remove_testplan.push(testplan)
    
        run_id = testplan['entries'][0]['runs'][0]['id']
        extra_fields = { 
          'run_id' => run_id, 
          'case_id' => testcase['id'] ,
          'section_id' => section['id']
        }
        testresult,testresult_id = create_testrail_artifact(@connection_testresult, extra_fields)
        @items_to_remove_testresult.push(testresult)
        
        story_fields = { 
          'Project' => TestConfig::RALLY_PROJECT_HIERARCHICAL_CHILD_OID, #a child project
          TestConfig::TR_RALLY_FIELD_TO_HOLD_PLAN_ID => testplan['id'] #associate story with plan
        }
        rally_story, rally_id = YetiTestUtils::create_arbitrary_rally_artifact('HierarchicalRequirement',@rally_connection, story_fields)
        @items_to_remove_rally.push(rally_story)
    
        @service_action = RallyEIF::WRK::PostServiceActions::CreateTestSets.new()
        @service_action.setup('', @rally_connection, @connection_testresult)
        @service_action.perform_post_service_action(:copy_to_rally,[])
        
        created_test_set = @service_action.find_rally_test_set_by_name("#{run_id}:") 
        expect(created_test_set).to_not be_nil
        expect(created_test_set.Project.ObjectID).to eq("#{TestConfig::RALLY_PROJECT_HIERARCHICAL_CHILD_OID}")
        
  end
  
  it "should put the test set into the same iteration as a story that is linked to the test run's test plan" do
    #
    suite,suite_id = create_testrail_artifact(@connection_testsuite, nil)
    @items_to_remove_testsuite.push(suite)

    extra_fields = {'suite_id' => suite_id}
    section,section_id = create_testrail_artifact(@connection_testsection, extra_fields)
    @items_to_remove_testsection.push(section)

    extra_fields = {'section_id' => section_id}
    testcase,testcase_id = create_testrail_artifact(@connection_testcase, extra_fields)
    @connection_testcase.update_external_id_fields(testcase, @unique_number , nil, nil)
    @items_to_remove_testcase.push(testcase)
    
    extra_fields =  {'entries' => [{  'suite_id'    => suite_id,
                      'include_all' => false,
                      'case_ids'    => [testcase_id],
                      'runs'        => [{  'include_all' => false, # Override selection
                                            'case_ids'   => [testcase_id]
                                       }]
                  }]
    }
    testplan,testplan_id = create_testrail_artifact(@connection_testplan, extra_fields)
    @items_to_remove_testplan.push(testplan)

    run_id = testplan['entries'][0]['runs'][0]['id']
    extra_fields = { 
      'run_id' => run_id, 
      'case_id' => testcase['id'] ,
      'section_id' => section['id']
    }
    testresult,testresult_id = create_testrail_artifact(@connection_testresult, extra_fields)
    @items_to_remove_testresult.push(testresult)
    
    iteration_fields = {
      "StartDate" => '2015-05-10',
      "EndDate" => '2015-05-11',
      "State" => "Planning"
    }
    rally_iteration, rally_iteration_id = YetiTestUtils::create_arbitrary_rally_artifact('Iteration',@rally_connection, iteration_fields)
    @items_to_remove_rally.push(rally_iteration)
    
    story_fields = { 
      'Iteration' => rally_iteration,
      TestConfig::TR_RALLY_FIELD_TO_HOLD_PLAN_ID => testplan['id'] #associate story with plan
    }
    rally_story, rally_id = YetiTestUtils::create_arbitrary_rally_artifact('HierarchicalRequirement',@rally_connection, story_fields)
    @items_to_remove_rally.push(rally_story)

    @service_action = RallyEIF::WRK::PostServiceActions::CreateTestSets.new()
    @service_action.setup('', @rally_connection, @connection_testresult)
    @service_action.perform_post_service_action(:copy_to_rally,[])
    
    created_test_set = @service_action.find_rally_test_set_by_name("#{run_id}:") 
    expect(created_test_set).to_not be_nil
    expect(created_test_set.Iteration.ObjectID).to eq(iteration.ObjectID)
    
  end
  
  it "should put the test set into the default project if there is not a story linked to the test run's test plan" do
    suite,suite_id = create_testrail_artifact(@connection_testsuite, nil)
    @items_to_remove_testsuite.push(suite)

    extra_fields = {'suite_id' => suite_id}
    section,section_id = create_testrail_artifact(@connection_testsection, extra_fields)
    @items_to_remove_testsection.push(section)

    extra_fields = {'section_id' => section_id}
    testcase,testcase_id = create_testrail_artifact(@connection_testcase, extra_fields)
    @connection_testcase.update_external_id_fields(testcase, @unique_number , nil, nil)
    @items_to_remove_testcase.push(testcase)
    
    extra_fields =  {'entries' => [{  'suite_id'    => suite_id,
                      'include_all' => false,
                      'case_ids'    => [testcase_id],
                      'runs'        => [{  'include_all' => false, # Override selection
                                            'case_ids'   => [testcase_id]
                                       }]
                  }]
    }
    testplan,testplan_id = create_testrail_artifact(@connection_testplan, extra_fields)
    @items_to_remove_testplan.push(testplan)

    run_id = testplan['entries'][0]['runs'][0]['id']
    extra_fields = { 
      'run_id' => run_id, 
      'case_id' => testcase['id'] ,
      'section_id' => section['id']
    }
    testresult,testresult_id = create_testrail_artifact(@connection_testresult, extra_fields)
    @items_to_remove_testresult.push(testresult)
    
    @service_action = RallyEIF::WRK::PostServiceActions::CreateTestSets.new()
    @service_action.setup('', @rally_connection, @connection_testresult)
    @service_action.perform_post_service_action(:copy_to_rally,[])
    
    created_test_set = @service_action.find_rally_test_set_by_name("#{run_id}:") 
    expect(created_test_set).to_not be_nil
    expect(created_test_set.Project.ObjectID).to eq("#{TestConfig::RALLY_PROJECT_HIERARCHICAL_PARENT_OID}")
    
  end
end