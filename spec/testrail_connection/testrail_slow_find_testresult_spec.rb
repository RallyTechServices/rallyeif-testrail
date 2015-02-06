require File.dirname(__FILE__) + '/../spec_helpers/spec_helper'
require File.dirname(__FILE__) + '/../spec_helpers/testrail_spec_helper'

include TestRailSpecHelper
include YetiTestUtils

describe "When trying to find TestRail test case results" do

  before(:each) do
    @connection_testcase = testrail_connect(TestRailSpecHelper::TESTRAIL_STATIC_CONFIG)
    @unique_number = (Time.now.strftime("%Y%m%d%H%M%S").to_i + Time.now.usec)

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
    
    @items_to_remove_testcase   = []
    @items_to_remove_testresult = []
    @items_to_remove_testrun    = []
  end
  
  after(:each) do    
     @items_to_remove_testresult.each { |item| @connection_testresult.delete(item) }
     @items_to_remove_testrun.each    { |item| @connection_testrun.delete(item)    }
     @items_to_remove_testcase.each   { |item| @connection_testcase.delete(item)   }

    @connection_testresult.disconnect()
    @connection_testrun.disconnect()
    @connection_testcase.disconnect()
  end
  
  # TODO: Must figure out how to add a TestCase TestResult,
  #       will probably have to create a TestCase first,
  #       then create a TestResult using add_result_for_case.
  # 
  it "(1), should find a Result that has a TestCase with an ExternalID but does NOT have its own ExternalID " do
    
    # 1 - Find all 'new' Results
    all_items_before = @connection_testresult.find_new()
    
    # 2 - Create a TestCase
    item_testcase,title = create_testrail_artifact(@connection_testcase)
    @connection_testcase.update_external_id_fields(item_testcase, @unique_number , nil, nil)
    @items_to_remove_testcase.push(item_testcase)
      
    # 3 - Create a Run
    item_testrun,run_id = create_testrail_artifact(@connection_testrun, { "include_all" => true })
    @connection_testrun.update_external_id_fields(item_testrun, @unique_number , nil, nil)
    @items_to_remove_testrun.push(item_testrun)
    
    # 4 - Create a TestResult
    item_testresult,testresult_id = create_testrail_artifact(@connection_testresult, {'run_id'  => run_id,
                                                                                      'case_id' => item_testcase['id']})
    @items_to_remove_testresult.push(item_testresult)
    
    # 5 - Find all 'new' results again
    all_items_after = @connection_testresult.find_new()
    
    # 6 - Second find should have more...
    expect(all_items_after.length).to eq(all_items_before.length + 1)
  end

   
  it "(2), should NOT find a result that has a test case without an external ID" do

    # 1 - Find all 'new' TestResults.
    all_items_before = @connection_testresult.find_new()
    
    # 2 - Create a TestCase.
    item_testcase,title = create_testrail_artifact(@connection_testcase)
    @items_to_remove_testcase.push(item_testcase)
   
    # 3 - Create a TestRun.
    item_testrun,run_id = create_testrail_artifact(@connection_testrun, { "include_all" => true })
    @connection_testrun.update_external_id_fields(item_testrun, @unique_number , nil, nil)
    @items_to_remove_testrun.push(item_testrun)
    
    # 4 - Create a TestResult for the TestCase.
    item_testresult,testresult_id = create_testrail_artifact(@connection_testresult, {'run_id'  => run_id,
                                                                                      'case_id' => item_testcase['id']})
    @items_to_remove_testresult.push(item_testresult)
    
    # 5 - Find all 'new' TestResults again.
    all_items_after = @connection_testresult.find_new()

    # 6 - Second find should have more...
    expect(all_items_after.length).to eq(all_items_before.length)
  end

end