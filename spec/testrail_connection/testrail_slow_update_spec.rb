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
      @connection.delete(item)
    end
    @connection.disconnect()
  end
  
  it "(1), should update a new test case with an externalid" do
    #1 create item with no external id
    item,title = create_testrail_artifact(@connection)
    @items_to_remove.push(item)

    #2 update ext id
    new_id_value = 2147483647
    @connection.update_external_id_fields(item, new_id_value, nil, nil)
    
    #3 verify was placed properly
    found_item = @connection.find(item)
    sys_name = 'custom_' + @connection.external_id_field.to_s.downcase
    expect(found_item[sys_name]).to eq(new_id_value)
  end
  
  it "(2), should not fail if no <CrosslinkUrlField> is defined" do
    #1 create item
    item,title = create_testrail_artifact(@connection)
    @items_to_remove.push(item)
    
    #2 update field
    @connection.update_external_id_fields(item, nil, nil, "<a href='http://www.rallydev.com'>Click for Rally!</a>")
    
    #3 verify was placed properly
    found_item = @connection.find(item)
    sys_name = 'custom_' + TestConfig::TR_CROSSLINK_FIELD.downcase
    expect(found_item[sys_name]).to be_nil
  end

  it "(3), should update a new case with an external_item_link_field (<CrosslinkUrlField>)" do
    @connection = testrail_connect(TestRailSpecHelper::TESTRAIL_EXTERNAL_FIELDS_CONFIG)
    
    #1 create item
    item,title = create_testrail_artifact(@connection)
    @items_to_remove.push(item)
    
    #2 update field
    # Rally gives us:  https://rally1.rallydev.com/#/745298d/detail/defect/5563341
    new_url  = 'http://rally1.rallydev.com/#/1d/detail/defect/2'
    new_href = "<a href='#{new_url}'>Click for Rally!</a>"
    @connection.update_external_id_fields(item, nil, nil, "#{new_href}")
    
    #3 verify was placed properly
    found_item = @connection.find(item)
    sys_name = 'custom_' + TestConfig::TR_CROSSLINK_FIELD.downcase
    expect(found_item[sys_name]).to eq("#{new_url}")
  end
  
  it "(4), should update a new case with an external_end_user_id_field (ExternalEndUserIDField)" do
     @connection = testrail_connect(TestRailSpecHelper::TESTRAIL_EXTERNAL_FIELDS_CONFIG)
     
     #1 create item with no id
     item,title = create_testrail_artifact(@connection)
     @items_to_remove.push(item)
     
     #2 update the external_end_user_id_field
     new_fmtid = 'DE1234'
     @connection.update_external_id_fields(item, nil, new_fmtid, nil)
     
     #3 verify was placed properly
     found_item = @connection.find(item)
     sys_name = 'custom_' + TestConfig::TR_EXTERNAL_EU_ID_FIELD.downcase
     expect(found_item[sys_name]).to eq(new_fmtid)
   end

  it "(5), should update a existing case using update_internal" do
    #1 create item
    item,title = create_testrail_artifact(@connection)
    @items_to_remove.push(item)
    
    #2 update the subject field
    title += "... and more title"
    @connection.update_internal(item, {'title' => "#{title}"})
    
    #3 verify was placed properly
    found_item = @connection.find(item)
    expect(found_item['title']).to eq(title)
  end
  
  it "(6), should update two fields on a existing case" do
    #1 create item
    item,title = create_testrail_artifact(@connection)
    @items_to_remove.push(item)
    
    #2 update the title & description fields
    title += ".... and more title"
    estimate = '1h 2m 3s'
    @connection.update_internal(item, {'title' => "#{title}", 'estimate' => "#{estimate}"})

    #3 verify fields were changed
    found_item = @connection.find(item)
    expect(found_item['title']).to eq(title)
    expect(found_item['estimate']).to eq(estimate)
  end
  
 end