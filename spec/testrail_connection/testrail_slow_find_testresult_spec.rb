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
    @connection_testcase = testrail_connect(TestRailSpecHelper::TESTRAIL_STATIC_CONFIG)
    @unique_number = Time.now.strftime("%Y%m%d%H%M%S") + Time.now.usec.to_s

    # Make a "TestResult" connection.
    config_testresult = YetiTestUtils::modify_config_data(
        TestRailSpecHelper::TESTRAIL_STATIC_CONFIG, #1 CONFIG  - The config file to be augmented
        "TestRailConnection",                       #2 SECTION - XML element of CONFIG to be augmented
        "ArtifactType",                             #3 NEWTAG  - New tag name in reference to REFTAG
        'TestResult',                               #4 VALUE   - New value to put into NEWTAG
        "replace",                                  #5 ACTION  - [before, after, replace, delete]
        "ArtifactType")                             #6 REFTAG  - Existing tag in SECTION
    @connection_testresult = testrail_connect(config_testresult)
    
    # Make a "TestRun" connection.
    config_testrun = YetiTestUtils::modify_config_data(
        TestRailSpecHelper::TESTRAIL_STATIC_CONFIG, #1 CONFIG  - The config file to be augmented
        "TestRailConnection",                       #2 SECTION - XML element of CONFIG to be augmented
        "ArtifactType",                             #3 NEWTAG  - New tag name in reference to REFTAG
        'TestRun',                                  #4 VALUE   - New value to put into NEWTAG
        "replace",                                  #5 ACTION  - [before, after, replace, delete]
        "ArtifactType")                             #6 REFTAG  - Existing tag in SECTION
    @connection_testrun = testrail_connect(config_testrun)

    # Make a "Test Plan" connection.
    config_testplan = YetiTestUtils::modify_config_data(
        TestRailSpecHelper::TESTRAIL_STATIC_CONFIG, #1 CONFIG  - The config file to be augmented
        "TestRailConnection",                       #2 SECTION - XML element of CONFIG to be augmented
        "ArtifactType",                             #3 NEWTAG  - New tag name in reference to REFTAG
        'TestPlan',                                 #4 VALUE   - New value to put into NEWTAG
        "replace",                                  #5 ACTION  - [before, after, replace, delete]
        "ArtifactType")                             #6 REFTAG  - Existing tag in SECTION
    @connection_testplan = testrail_connect(config_testplan)
        
    @items_to_remove_testcase   = []
    @items_to_remove_testresult = []
    @items_to_remove_testrun    = []
    @items_to_remove_testplan   = []
  end
  
  after(:each) do    
     @items_to_remove_testresult.each { |item| @connection_testresult.delete(item) }
     @items_to_remove_testrun.each    { |item| @connection_testrun.delete(item)    }
     @items_to_remove_testplan.each   { |item| @connection_testplan.delete(item)   }
     @items_to_remove_testcase.each   { |item| @connection_testcase.delete(item)   }
  end
  
  it "(1), should find a Result that has a TestCase with an ExternalID but does NOT have its own ExternalID " do
    
    # 1 - Find all 'new' Results
    all_items_before = @connection_testresult.find_new()
    
    # 2 - Create a TestCase
    testcase,title = create_testrail_artifact(@connection_testcase)
    @connection_testcase.update_external_id_fields(testcase, @unique_number , nil, nil)
    @items_to_remove_testcase.push(testcase)
      
    # 3 - Create a Run
    extra_fields = { 'include_all' => true, 'suite_id' => testcase['suite_id'] }
    testrun,run_id = create_testrail_artifact(@connection_testrun, extra_fields)
    @connection_testrun.update_external_id_fields(testrun, @unique_number , nil, nil)
    @items_to_remove_testrun.push(testrun)
    
    # 4 - Create a TestResult
    extra_fields = { 'run_id'  => run_id, 'case_id' => testcase['id'] }
    testresult,testresult_id = create_testrail_artifact(@connection_testresult, extra_fields)
    @items_to_remove_testresult.push(testresult)
    
    # 5 - Find all 'new' results again
    all_items_after = @connection_testresult.find_new()
    
    # 6 - Second find should have more...
    expect(all_items_after.length).to eq(all_items_before.length + 1)
  end

  it "(2), should find new results multiple test cases" do
    
    # 1 - Find all 'new' Results
    all_items_before = @connection_testresult.find_new()
    
    # 2 - Create 2 TestCases
    testcase1,title1 = create_testrail_artifact(@connection_testcase)
    @connection_testcase.update_external_id_fields(testcase1, @unique_number , nil, nil)
    @items_to_remove_testcase.push(testcase1)
    
    testcase2,title2 = create_testrail_artifact(@connection_testcase)
    @connection_testcase.update_external_id_fields(testcase2, @unique_number , nil, nil)
    @items_to_remove_testcase.push(testcase2)
          
    # 3 - Create 2 runs
    extra_fields = { 'include_all' => true, 'suite_id' => testcase1['suite_id'] }
    run1,run_id1 = create_testrail_artifact(@connection_testrun, extra_fields)
    @connection_testrun.update_external_id_fields(run1, @unique_number , nil, nil)
    @items_to_remove_testrun.push(run1)
    
    extra_fields = { 'include_all' => true, 'suite_id' => testcase2['suite_id'] }
    run2,run_id2 = create_testrail_artifact(@connection_testrun, extra_fields)
    @connection_testrun.update_external_id_fields(run2, @unique_number , nil, nil)
    @items_to_remove_testrun.push(run2)
        
    # 4 - Create 3 TestResults
    extra_fields = { 'run_id' => run_id1, 'case_id' => testcase1['id'] }
    result1,testresult_id1 = create_testrail_artifact(@connection_testresult, extra_fields)
    @items_to_remove_testresult.push(result1)
    
    extra_fields = { 'run_id' => run_id1, 'case_id' => testcase2['id'] }
    result2,testresult_id2 = create_testrail_artifact(@connection_testresult, extra_fields)
    @items_to_remove_testresult.push(result2)
    
    extra_fields = { 'run_id' => run_id2, 'case_id' => testcase2['id'] }
    result3,testresult_id3 = create_testrail_artifact(@connection_testresult, extra_fields)
    @items_to_remove_testresult.push(result3)
    
    # 5 - Find all 'new' results again
    all_items_after = @connection_testresult.find_new()
    
    # 6 - Second find should have more...
    expect(all_items_after.length).to eq(all_items_before.length + 3)
  end
  
  
  it "(3), should find a Result from a run inside a test plan" do
    
    # 1 - Find all 'new' Results
    all_items_before = @connection_testresult.find_new()
    
    # create a test plan
    testplan,title = create_testrail_artifact(@connection_testplan)
    @items_to_remove_testplan.push(testplan)
    
    # 2 - Create a TestCase
    testcase,title = create_testrail_artifact(@connection_testcase)
    @connection_testcase.update_external_id_fields(testcase, @unique_number , nil, nil)
    @items_to_remove_testcase.push(testcase)
      
    # Create a run in the plan
    projid = @connection_testplan.tr_project['id']
    suids = @connection_testplan.all_suites
    updated_plan = @connection_testplan.add_run_to_plan({ 'suite_id' => suids[0]['id'] },testplan)
    
    runs = updated_plan['runs']
    run = runs[0]
    
    # 4 - Create a TestResult
    extra_fields = { 'run_id' => run['id'], 'case_id' => testcase['id'] }
    testresult,testresult_id = create_testrail_artifact(@connection_testresult, extra_fields)
    @items_to_remove_testresult.push(testresult)
    
    # 5 - Find all 'new' results again
    all_items_after = @connection_testresult.find_new()
    
    # 6 - Second find should have more...
    expect(all_items_after.length).to eq(all_items_before.length + 1)
  end
  
  
  it "(4), should NOT find a result that has a test case without an external ID" do

    # 1 - Find all 'new' TestResults.
    all_items_before = @connection_testresult.find_new()
    
    # 2 - Create a TestCase.
    testcase,title = create_testrail_artifact(@connection_testcase)
    @items_to_remove_testcase.push(testcase)
   
    # 3 - Create a TestRun.
    extra_fields = { 'include_all' => true, 'suite_id' => testcase['suite_id'] }
    testrun,run_id = create_testrail_artifact(@connection_testrun, extra_fields)
    @connection_testrun.update_external_id_fields(testrun, @unique_number , nil, nil)
    @items_to_remove_testrun.push(testrun)
    
    # 4 - Create a TestResult for the TestCase.
    testresult,testresult_id = create_testrail_artifact(@connection_testresult, {'run_id'  => run_id,
                                                                                 'case_id' => testcase['id']})
    @items_to_remove_testresult.push(testresult)
    
    # 5 - Find all 'new' TestResults again.
    all_items_after = @connection_testresult.find_new()

    # 6 - Second find should have more...
    expect(all_items_after.length).to eq(all_items_before.length)
  end

  it "(5), should raise an exception when trying to find update on a test result (only do new) " do
    # we want to only do updates because we cannot set the external ID on a test result
    
    # 1 - Find all 'new' Results
    time = (Time.now() - 600).utc

    expect{ @connection_testresult.find_updates(time) }.to raise_error(/Not available for "testresult"/)
    
  end
  
end