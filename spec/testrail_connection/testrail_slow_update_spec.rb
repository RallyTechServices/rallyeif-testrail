require File.dirname(__FILE__) + '/../spec_helpers/spec_helper'
require File.dirname(__FILE__) + '/../spec_helpers/testrail_spec_helper'

include TestRailSpecHelper
include YetiTestUtils

describe "When trying to update TestRail items" do
  before(:each) do
    @connection = testrail_connect(TestRailSpecHelper::TESTRAIL_STATIC_CONFIG)
    @items_to_remove = []
  end
  
  after(:each) do    
    @items_to_remove.each do |item|
      item.delete
    end
    @connection.disconnect()
  end
  
  it "(1), should update a new test case with an externalid" do
  
    #1 create item with no id
    item,name = create_testrail_testcase(@connection)
    @items_to_remove.push(item)

    #2 update ext id
    @connection.update_external_id_fields(item, '2147483647', nil, nil)
    
    #3 verify was placed properly
    found_item = @connection.artifact_class.find(item['Id'])
    expect(found_item[TestConfig::TR_EXTERNAL_ID_FIELD]).to eq '2147483647'
    
  end
  
  it "(2), should not fail if no <CrosslinkUrlField> is defined" do
    
    #1 create item with no id
    item,name = create_testrail_artifact(@connection)
    @items_to_remove.push(item)
    
    #2 update ext id
    @connection.update_external_id_fields(item, nil, nil, "<a href='http://www.rallydev.com'>Click for Rally!</a>")
    
    #3 verify was placed properly
    found_item = @connection.artifact_class.find(item['Id'])
    expect(found_item[TestConfig::TR_CROSSLINK_FIELD]).to be_nil
    
  end

  it "(3), should update a new case with an external_item_link_field (CrosslinkUrl)" do
    
    @connection = testrail_connect(TestRailSpecHelper::TESTRAIL_EXTERNAL_FIELDS_CONFIG)
    
    #1 create item with no id
    item,name = create_testrail_artifact(@connection)
    @items_to_remove.push(item)
    
    #2 update ext id
    # Rally gives us:  https://rally1.rallydev.com/#/745298d/detail/defect/5563341
    @connection.update_external_id_fields(item, nil, nil, "<a href='https://rally1.rallydev.com/#/745298d/detail/defect/5563341'>Click for Rally!</a>")
    
    #3 verify was placed properly
    found_item = @connection.artifact_class.find(item['Id'])
    expect(found_item[TestConfig::TR_CROSSLINK_FIELD]).to eq "https://rally1.rallydev.com/#/745298d/detail/defect/5563341"
    
  end
  
  it "(4), should update a new case with an external_end_user_id_field (ExternalEndUserIDField)" do
     
     @connection = testrail_connect(TestRailSpecHelper::TESTRAIL_EXTERNAL_FIELDS_CONFIG)
     
     #1 create item with no id
     item,name = create_testrail_artifact(@connection)
     @items_to_remove.push(item)
     
     #2 update the external_end_user_id_field
     @connection.update_external_id_fields(item, nil, "DE1234", nil)
     
     #3 verify was placed properly
     found_item = @connection.artifact_class.find(item['Id'])
     expect(found_item[TestConfig::TR_EXTERNAL_EU_ID_FIELD]).to eq "DE1234"
     
   end

  it "(5), should update a existing case using update_internal" do
    
    #1 create item
    item,subject = create_testrail_artifact(@connection)
    @items_to_remove.push(item)
    
    #2 update the subject field
    @connection.update_internal(item, {'Subject' => "#{subject} + more"})
    
    #3 verify was placed properly
    found_item = @connection.artifact_class.find(item['Id'])
    expect(found_item['Subject']).to eq "#{subject} + more"
    
  end
  
  it "(6), should update two fields on a existing case" do
    
    #1 create item
    item,subject = create_testrail_artifact(@connection)
    @items_to_remove.push(item)
    
    #2 update the subject & description fields
    @connection.update_internal(item, {'Subject' => "#{subject} + more", 'Description' => 'New description from test'})
    
    #3 verify fields were changed
    found_item = @connection.artifact_class.find(item['Id'])
    expect(found_item['Subject']).to eq "#{subject} + more"
    expect(found_item['Description']).to eq "New description from test"
      
  end
  
 end