require File.dirname(__FILE__) + '/../spec_helpers/spec_helper'
require File.dirname(__FILE__) + '/../spec_helpers/testrail_spec_helper'

include TestRailSpecHelper
include YetiTestUtils

describe "When trying to find TestRail test case results" do

  before(:each) do
    @connection = testrail_connect(TestRailSpecHelper::TESTRAIL_STATIC_CONFIG)
    @unique_number = Time.now.strftime("%Y%m%d%H%M%S") + Time.now.usec.to_s

    tcr_config = YetiTestUtils::modify_config_data(
        TestRailSpecHelper::TESTRAIL_STATIC_CONFIG, #1 CONFIG  - The config file to be augmented
        "TestRailConnection",                       #2 SECTION - XML element of CONFIG to be augmented
        "ArtifactType",                             #3 NEWTAG  - New tag name in reference to REFTAG
        'TestResult',                               #4 VALUE   - New value to put into NEWTAG
        "replace",                                  #5 ACTION  - [before, after, replace, delete]
        "ArtifactType")                             #6 REFTAG  - Existing tag in SECTION
    @tcr_connection = testrail_connect(tcr_config)
        
    @items_to_remove = []
  end
  
  after(:each) do    
    @items_to_remove.each do |item|
      @connection.delete(item)
    end
    @connection.disconnect()
  end
  
  # TODO: Will have to figure out how to add a test case result, probably have to create a test first,
  #       then create a test result using add_result_for_case
  # 
  it "(1), should find a result that has a test case with an external ID but does NOT have its own externalID " do
    #1 find all 'new' results
    all_items_before = @tcr_connection.find_new()
    
    #2 create test case
    item,title = create_testrail_artifact(@connection)
    @connection.update_external_id_fields(item, @unique_number , nil, nil)
    @items_to_remove.push(item)
   
    #3 create test result for the test case
    result,result_title = create_testrail_artifact(@tcr_connection, {
      status_id => 1,  # 1=passed
      test_id => @connection.get_id_value(item)
    })
    @items_to_remove.push(result)
    
    #4 find all 'new' results again
    all_items_after = @tcr_connection.find_new()
    
    #4 second find should have more...
    expect(all_items_before.length).to be < (all_items_after.length)
  end
  
  it "(2), should NOT find a result that has a test case with an external ID and has its own externalID " do
    #1 find all 'new' results
    all_items_before = @tcr_connection.find_new()
    
    #2 create test case
    item,title = create_testrail_artifact(@connection)
    @connection.update_external_id_fields(item, @unique_number , nil, nil)
    @items_to_remove.push(item)
   
    #3 create test result for the test case
    result,result_title = create_testrail_artifact(@tcr_connection, {
      status_id => 1,  # 1=passed
      test_id => @connection.get_id_value(item)
    })
    @tcr_connection.update_external_id_fields(result, @unique_number + 25 , nil, nil)
    @items_to_remove.push(result)
    
    #4 find all 'new' results again
    all_items_after = @tcr_connection.find_new()
    
    #4 second find should have more...
    expect(all_items_before.length).to eq(all_items_after.length)
  end
  
  it "(3), should NOT find a result that has a test case without an external ID" do
    #1 find all 'new' results
    all_items_before = @tcr_connection.find_new()
    
    #2 create test case
    item,title = create_testrail_artifact(@connection)
    @items_to_remove.push(item)
   
    #3 create test result for the test case
    result,result_title = create_testrail_artifact(@tcr_connection, {
      status_id => 1,  # 1=passed
      test_id => @connection.get_id_value(item)
    })
    @items_to_remove.push(result)
    
    #4 find all 'new' results again
    all_items_after = @tcr_connection.find_new()
    
    #4 second find should have more...
    expect(all_items_before.length).to eq(all_items_after.length)
  end  
 end