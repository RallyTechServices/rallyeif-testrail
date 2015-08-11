require File.dirname(__FILE__) + '/../spec_helpers/spec_helper'
require File.dirname(__FILE__) + '/../spec_helpers/testrail_spec_helper'

include TestRailSpecHelper
include YetiTestUtils

##
## NOTE
## These tests work because we create test runs
## which default to containing tests for all existing test cases
##

describe "When trying to find TestRail test case results" do

  before(:each) do
    
    # Make a "TestResult" connection.
    config_testresult = YetiTestUtils::modify_config_data(
        TestRailSpecHelper::TESTRAIL_STATIC_CONFIG, #1 CONFIG  - The config file to be augmented
        "TestRailConnection",                       #2 SECTION - XML element of CONFIG to be augmented
        "ArtifactType",                             #3 NEWTAG  - New tag name in reference to REFTAG
        'TestResult',                               #4 VALUE   - New value to put into NEWTAG
        "replace",                                  #5 ACTION  - [before, after, replace, delete]
        "ArtifactType")                             #6 REFTAG  - Existing tag in SECTION
    
    # Make a "TestRun" connection.
    config_testrun = YetiTestUtils::modify_config_data(
        TestRailSpecHelper::TESTRAIL_STATIC_CONFIG, #1 CONFIG  - The config file to be augmented
        "TestRailConnection",                       #2 SECTION - XML element of CONFIG to be augmented
        "ArtifactType",                             #3 NEWTAG  - New tag name in reference to REFTAG
        'TestRun',                                  #4 VALUE   - New value to put into NEWTAG
        "replace",                                  #5 ACTION  - [before, after, replace, delete]
        "ArtifactType")                             #6 REFTAG  - Existing tag in SECTION

    # Make a "Test Plan" connection.
    config_testplan = YetiTestUtils::modify_config_data(
        TestRailSpecHelper::TESTRAIL_STATIC_CONFIG, #1 CONFIG  - The config file to be augmented
        "TestRailConnection",                       #2 SECTION - XML element of CONFIG to be augmented
        "ArtifactType",                             #3 NEWTAG  - New tag name in reference to REFTAG
        'TestPlan',                                 #4 VALUE   - New value to put into NEWTAG
        "replace",                                  #5 ACTION  - [before, after, replace, delete]
        "ArtifactType")                             #6 REFTAG  - Existing tag in SECTION
    
    # Make a "Test Suite" connection.
    config_testsuite = YetiTestUtils::modify_config_data(
        TestRailSpecHelper::TESTRAIL_STATIC_CONFIG, #1 CONFIG  - The config file to be augmented
        "TestRailConnection",                       #2 SECTION - XML element of CONFIG to be augmented
        "ArtifactType",                             #3 NEWTAG  - New tag name in reference to REFTAG
        'TestSuite',                                #4 VALUE   - New value to put into NEWTAG
        "replace",                                  #5 ACTION  - [before, after, replace, delete]
        "ArtifactType")                             #6 REFTAG  - Existing tag in SECTION

    # Make a "Test Section" connection.
    config_testsection = YetiTestUtils::modify_config_data(
        TestRailSpecHelper::TESTRAIL_STATIC_CONFIG, #1 CONFIG  - The config file to be augmented
        "TestRailConnection",                       #2 SECTION - XML element of CONFIG to be augmented
        "ArtifactType",                             #3 NEWTAG  - New tag name in reference to REFTAG
        'TestSection',                              #4 VALUE   - New value to put into NEWTAG
        "replace",                                  #5 ACTION  - [before, after, replace, delete]
        "ArtifactType")                             #6 REFTAG  - Existing tag in SECTION    
    @unique_number = Time.now.strftime("%Y%m%d%H%M%S") + Time.now.usec.to_s
    
    @connection_testcase    = testrail_connect(TestRailSpecHelper::TESTRAIL_STATIC_CONFIG)
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
  end
  
  after(:each) do    
    @items_to_remove_testcase.each   { |item| @connection_testcase.delete(item)   } 
    @items_to_remove_testresult.each { |item| @connection_testresult.delete(item) }
    @items_to_remove_testrun.each    { |item| @connection_testrun.delete(item)    }
    @items_to_remove_testplan.each   { |item| @connection_testplan.delete(item)   }
    @items_to_remove_testsuite.each  { |item| @connection_testsuite.delete(item)  }
    @items_to_remove_testsection.each{ |item| @connection_testsection.delete(item)}
  end
  
  it "(1), should find a Result that has a TestCase with an ExternalID but does NOT have its own ExternalID " do
    
    # 1 - Find all 'new' Results
    all_items_before = @connection_testresult.find_new()
    
    # 2 - Create a Suite
    suite,suite_id = create_testrail_artifact(@connection_testsuite, nil)
    @items_to_remove_testsuite.push(suite)

    # 3 - Create a Section
    extra_fields = {'suite_id' => suite_id}
    section,section_id = create_testrail_artifact(@connection_testsection, extra_fields)
    @items_to_remove_testsection.push(section)

    # 4 - Create a TestCase
    extra_fields = {'section_id' => section_id}
    testcase,testcase_id = create_testrail_artifact(@connection_testcase, extra_fields)
    @connection_testcase.update_external_id_fields(testcase, @unique_number , nil, nil)
    @items_to_remove_testcase.push(testcase)
    
    # 5 - Create a plan with a run of a single case
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

    # 6 - Create a TestResult
    extra_fields = { 'run_id' => testplan['entries'][0]['runs'][0]['id'], 'case_id' => testcase['id'] }
    testresult,testresult_id = create_testrail_artifact(@connection_testresult, extra_fields)
    @items_to_remove_testresult.push(testresult)
    
    # 7 - Find all 'new' results again
    all_items_after = @connection_testresult.find_new()
    
    # 8 - Second find should have more...
    expect(all_items_after.length).to eq(all_items_before.length + 1)
  end

  it "(2), should find new results multiple test cases" do
    
    # 1 - Find all 'new' Results
    all_items_before = @connection_testresult.find_new()

    # 2 - Create a Suite
    suite,suite_id = create_testrail_artifact(@connection_testsuite, nil)
    @items_to_remove_testsuite.push(suite)

    # 3 - Create a Section
    extra_fields = {'suite_id' => suite_id}
    section,section_id = create_testrail_artifact(@connection_testsection, extra_fields)
    @items_to_remove_testsection.push(section)

    # 4 - Create 2 TestCases
    extra_fields = {'section_id' => section_id}
    testcase1,testcase1_id = create_testrail_artifact(@connection_testcase, extra_fields)
    @connection_testcase.update_external_id_fields(testcase1, @unique_number , nil, nil)
    @items_to_remove_testcase.push(testcase1)
    
    testcase2,testcase2_id = create_testrail_artifact(@connection_testcase, extra_fields)
    @connection_testcase.update_external_id_fields(testcase2, @unique_number , nil, nil)
    @items_to_remove_testcase.push(testcase2)

    # 5 - Create a plan with two runs, one for each testcase
    extra_fields = {'entries' => [{ 'suite_id'    => suite_id,
                                    'include_all' => false,
                                    'case_ids'    => [testcase1_id]},
                                    
                                  { 'suite_id'    => suite_id,
                                    'include_all' => false,
                                    'case_ids'    => [testcase2_id]}
                                 ]
                   }
    testplan,testplan_id = create_testrail_artifact(@connection_testplan, extra_fields)
    @items_to_remove_testplan.push(testplan)
    
    # 6 - Create 3 TestResults
    extra_fields = { 'run_id' => testplan['entries'][0]['runs'][0]['id'], 'case_id' => testcase1_id }
    testresult1,testresult_id1 = create_testrail_artifact(@connection_testresult, extra_fields)
    @items_to_remove_testresult.push(testresult1)

    extra_fields = { 'run_id' => testplan['entries'][1]['runs'][0]['id'], 'case_id' => testcase2_id }
    testresult2,testresult_id2 = create_testrail_artifact(@connection_testresult, extra_fields)
    @items_to_remove_testresult.push(testresult2)
    
    extra_fields = { 'run_id' => testplan['entries'][1]['runs'][0]['id'], 'case_id' => testcase2_id }
    testresult3,testresult_id3 = create_testrail_artifact(@connection_testresult, extra_fields)
    @items_to_remove_testresult.push(testresult3)
 
    # 7 - Find all 'new' results again
    all_items_after = @connection_testresult.find_new()
    
    # 8 - Second find should have more...
    expect(all_items_after.length).to eq(all_items_before.length + 3)
  end
  
  
  it "(3), should find a Result from a run inside a test plan" do
    
    # 1 - Find all 'new' Results
    all_items_before = @connection_testresult.find_new()
    
    # 2 - Create a Suite
    suite,suite_id = create_testrail_artifact(@connection_testsuite, nil)
    @items_to_remove_testsuite.push(suite)

    # 3 - Create a Section
    extra_fields = {'suite_id' => suite_id}
    section,section_id = create_testrail_artifact(@connection_testsection, extra_fields)
    @items_to_remove_testsection.push(section)
    
    # 4 - Create a TestCase
    extra_fields = {'section_id' => section_id}
    testcase,testcase_id = create_testrail_artifact(@connection_testcase, extra_fields)
    @connection_testcase.update_external_id_fields(testcase, @unique_number , nil, nil)
    @items_to_remove_testcase.push(testcase)
    
    # 5 - Create a plan with one run for the testcase
    extra_fields = {'entries' => [{ 'suite_id'    => suite_id,
                                    'include_all' => false,
                                    'case_ids'    => [testcase_id]}
                                 ]
                   }
    testplan,testplan_id = create_testrail_artifact(@connection_testplan, extra_fields)
    @items_to_remove_testplan.push(testplan)

    # 6 - Create a TestResult
    extra_fields = { 'run_id' => testplan['entries'][0]['runs'][0]['id'], 'case_id' => testcase_id }
    testresult,testresult_id = create_testrail_artifact(@connection_testresult, extra_fields)
    @items_to_remove_testresult.push(testresult)
    
    # 7 - Find all 'new' TestResults again
    all_items_after = @connection_testresult.find_new()
    
    # 8 - Second find should have more...
    expect(all_items_after.length).to eq(all_items_before.length + 1)
  end
  
  
  it "(4), should NOT find a result that has a test case without an external ID" do

    # 1 - Find all 'new' TestResults.
    all_items_before = @connection_testresult.find_new()
    
    # 2 - Create a Suite
    suite,suite_id = create_testrail_artifact(@connection_testsuite, nil)
    @items_to_remove_testsuite.push(suite)

    # 3 - Create a Section
    extra_fields = {'suite_id' => suite_id}
    section,section_id = create_testrail_artifact(@connection_testsection, extra_fields)
    @items_to_remove_testsection.push(section)
    
    # 4 - Create a TestCase
    extra_fields = {'section_id' => section_id}
    testcase,testcase_id = create_testrail_artifact(@connection_testcase, extra_fields)
    #@connection_testcase.update_external_id_fields(testcase, @unique_number , nil, nil)
    @items_to_remove_testcase.push(testcase)
    
    # 5 - Create a plan with one run for the testcase
    extra_fields = {'entries' => [{ 'suite_id'    => suite_id,
                                    'include_all' => false,
                                    'case_ids'    => [testcase_id]}
                                 ]
                   }
    testplan,testplan_id = create_testrail_artifact(@connection_testplan, extra_fields)
    @items_to_remove_testplan.push(testplan)

    # 6 - Create a TestResult
    extra_fields = { 'run_id' => testplan['entries'][0]['runs'][0]['id'], 'case_id' => testcase_id }
    testresult,testresult_id = create_testrail_artifact(@connection_testresult, extra_fields)
    @items_to_remove_testresult.push(testresult)
    
    # 7 - Find all 'new' TestResults again.
    all_items_after = @connection_testresult.find_new()

    # 8 - Second find should have more...
    expect(all_items_after.length).to eq(all_items_before.length)
  end

  it "(5), should raise an exception when trying to find update on a test result (only do new) " do
    # we want to only do updates because we cannot set the external ID on a test result
    
    # 1 - Find all 'new' Results
    time = (Time.now() - 600).utc

    expect{ @connection_testresult.find_updates(time) }.to raise_error(/Not available for "testresult"/)
    
  end
  
end