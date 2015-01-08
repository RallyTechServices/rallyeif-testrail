require File.dirname(__FILE__) + '/../spec_helpers/spec_helper'
require File.dirname(__FILE__) + '/../spec_helpers/testrail_spec_helper'

include TestRailSpecHelper
include YetiTestUtils

describe "When trying to find TestRail items" do
  before(:each) do
    @connection = testrail_connect(TestRailSpecHelper::TESTRAIL_STATIC_CONFIG)
    @items_to_remove = []
  end
  
  after(:each) do    
    @items_to_remove.each do |item|
      @connection.delete(item)
    end
    @connection.disconnect()
  end
  
  it "(1), should find new test case without an externalid" do
    #1 find all 'new' items
    all_items_before = @connection.find_new()
    
    #2 create item
    item,title = create_testrail_artifact(@connection)
    @items_to_remove.push(item)
   
    #3 find all 'new' items again
    all_items_after = @connection.find_new()
    
    #4 second find should have more...
    expect(all_items_before.length).to be < (all_items_after.length)
  end
  
  it "(2), should not find test case with an externalid" do
    #1 find all 'new' items
    all_items_before = @connection.find_new()
    
    #2 create item and give it an external id
    item,title = create_testrail_artifact(@connection)
    @items_to_remove.push(item)
    new_id_value = 2147483647
    @connection.update_external_id_fields(item, new_id_value, nil, nil)
   
    #3 find all 'new' items again
    all_items_after = @connection.find_new()
    
    #4 second find should have the same number of items
    expect(all_items_before.length).to eq(all_items_after.length)
  end
  
 end