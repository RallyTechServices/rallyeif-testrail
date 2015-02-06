require File.dirname(__FILE__) + '/../spec_helpers/spec_helper'
require File.dirname(__FILE__) + '/../spec_helpers/testrail_spec_helper'

include TestRailSpecHelper
include YetiTestUtils

describe "When trying to find TestRail items" do

  before(:each) do
    @connection = testrail_connect(TestRailSpecHelper::TESTRAIL_STATIC_CONFIG)
    @unique_number = Time.now.strftime("%Y%m%d%H%M%S") + Time.now.usec.to_s
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
    new_id_value = @unique_number
    @connection.update_external_id_fields(item, new_id_value, nil, nil)
   
    #3 find all 'new' items again
    all_items_after = @connection.find_new()
    
    #4 second find should have the same number of items
    expect(all_items_before.length).to eq(all_items_after.length)
  end
  
  it "(3), should not find test case without an externalid" do
    #1 find all 'updated' items
    time = (Time.now() - 600).utc
    all_items_before = @connection.find_updates(time)
    
    #2 create item and give an ID
    item,title = create_testrail_artifact(@connection)
    @connection.update_external_id_fields(item, @unique_number , nil, nil)
    @items_to_remove.push(item)
   
    #3 find all 'updated' items again
    all_items_after = @connection.find_updates(time)
    
    #4 second find should have more...
    expect(all_items_before.length).to be < (all_items_after.length)
  end

  it "(4), should not find updated test case without an externalid" do
    #1 find all 'updated' items
    time = (Time.now() - 600).utc
    all_items_before = @connection.find_updates(time)
    
    #2 create item (it will not have a externalID)
    item,title = create_testrail_artifact(@connection)
    @items_to_remove.push(item)
   
    #3 find all 'updated' items again (should not find our new item)
    all_items_after = @connection.find_updates(time)
    
    #4 second find should have more...
    expect(all_items_before.length).to eq(all_items_after.length)
    
    #5 second find should not contain this item
    found_me = false
    all_items_after.each do |found_item|
      if @connection.get_value(found_item,'title') == title
        found_me = true
      end
    end
    expect(found_me).to eq(false)
  end

  it "(5), should not find test case with an externalid updated before the timestamp" do
    #1 create item and give an ExternalID (it will have a timestamp of 'now')
    item,title = create_testrail_artifact(@connection)
    @connection.update_external_id_fields(item, @unique_number , nil, nil)
    @items_to_remove.push(item)
   
    #2 pause for 2 seconds, then find all items 'updated' after 'now'
    sleep (2.0)
    time = Time.now().utc
    all_items = @connection.find_updates(time)

    #3  find should not contain this item
    found_me = false
    all_items.each do |found_item|
      if @connection.get_value(found_item,'title') == title
        found_me = true
      end
    end
    expect(found_me).to eq(false)
  end
  
 end