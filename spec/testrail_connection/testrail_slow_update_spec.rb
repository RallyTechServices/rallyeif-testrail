require File.dirname(__FILE__) + '/../spec_helpers/spec_helper'
require File.dirname(__FILE__) + '/../spec_helpers/testrail_spec_helper'

include TestRailSpecHelper
include YetiTestUtils

describe "When trying to update TestRail items" do
  before(:each) do
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
    @connection_testsuite   = testrail_connect(config_testsuite)
    @connection_testsection = testrail_connect(config_testsection)
    
    @items_to_remove_testcase     = []
    @items_to_remove_testsuite    = []
    @items_to_remove_testsection  = []
  end

  after(:each) do    
    @items_to_remove_testcase.each   { |item| @connection_testcase.delete(item)   } 
    @items_to_remove_testsuite.each  { |item| @connection_testsuite.delete(item)  }
    @items_to_remove_testsection.each{ |item| @connection_testsection.delete(item)}
  end
  
#  after(:all) do
#    @connection_testcase.disconnect()
#    @connection_testsuite.disconnect()
#    @connection_testsection.disconnect()
#  end
  
  it "(1), should update a new test case with an externalid" do
    # 1 - Create a Suite
    suite,suite_id = create_testrail_artifact(@connection_testsuite, nil)
    @items_to_remove_testsuite.push(suite)

    # 2 - Create a Section
    extra_fields = {'suite_id' => suite_id}
    section,section_id = create_testrail_artifact(@connection_testsection, extra_fields)
    @items_to_remove_testsection.push(section)
    
    # 3 - Create a TestCase with no external id
    extra_fields = {'section_id' => section_id}
    testcase,testcase_id = create_testrail_artifact(@connection_testcase, extra_fields)
    @items_to_remove_testcase.push(testcase)

    # 4 - Update the ExternalID field of the TestCaase
    @connection_testcase.update_external_id_fields(testcase, @unique_number, nil, nil)
    
    # 5 - Verify it was placed properly
    found_item = @connection_testcase.find(testcase)
    sys_name = 'custom_' + @connection_testcase.external_id_field.to_s.downcase
    expect(found_item[sys_name]).to eq(@unique_number)
  end
  
  it "(2), should not fail if no <CrosslinkUrlField> is defined" do
    # 1 - Create a Suite
    suite,suite_id = create_testrail_artifact(@connection_testsuite, nil)
    @items_to_remove_testsuite.push(suite)

    # 2 - Create a Section
    extra_fields = {'suite_id' => suite_id}
    section,section_id = create_testrail_artifact(@connection_testsection, extra_fields)
    @items_to_remove_testsection.push(section)
    
    # 3 - Create a TestCase
    extra_fields = {'section_id' => section_id}
    testcase,testcase_id = create_testrail_artifact(@connection_testcase, extra_fields)
    @items_to_remove_testcase.push(testcase)
    
    # 4 - Update field
    @connection_testcase.update_external_id_fields(testcase, nil, nil, "<a href='http://www.rallydev.com'>Click for Rally!</a>")
    
    # 5 - Verify it was placed properly
    found_item = @connection_testcase.find(testcase)
    sys_name = 'custom_' + TestConfig::TR_CROSSLINK_FIELD.downcase
    expect(found_item[sys_name]).to be_nil
  end

  it "(3), should update a new case with an external_item_link_field (<CrosslinkUrlField>)" do
    @connection_tmp3 = testrail_connect(TestRailSpecHelper::TESTRAIL_EXTERNAL_FIELDS_CONFIG)
    
    # 1 - Create a Suite
    suite,suite_id = create_testrail_artifact(@connection_testsuite, nil)
    @items_to_remove_testsuite.push(suite)

    # 2 - Create a Section
    extra_fields = {'suite_id' => suite_id}
    section,section_id = create_testrail_artifact(@connection_testsection, extra_fields)
    @items_to_remove_testsection.push(section)
    
    # 3 - Create a TestCase
    extra_fields = {'section_id' => section_id}
    testcase,testcase_id = create_testrail_artifact(@connection_tmp3, extra_fields)
    @items_to_remove_testcase.push(testcase)
    
    # 4 - Update the field
    #     Rally gives us:  https://rally1.rallydev.com/#/745298d/detail/defect/5563341
    new_url  = 'http://rally1.rallydev.com/#/1d/detail/defect/2'
    new_href = "<a href='#{new_url}'>Click for Rally!</a>"
    @connection_tmp3.update_external_id_fields(testcase, nil, nil, "#{new_href}")
    
    # 5 - Verify it was placed properly
    found_item = @connection_tmp3.find(testcase)
    sys_name = 'custom_' + TestConfig::TR_CROSSLINK_FIELD.downcase
    expect(found_item[sys_name]).to eq("#{new_url}")
  end

  it "(4), should update a new case with an external_end_user_id_field (ExternalEndUserIDField)" do
    @connection_tmp4 = testrail_connect(TestRailSpecHelper::TESTRAIL_EXTERNAL_FIELDS_CONFIG)
     
    # 1 - Create a Suite
    suite,suite_id = create_testrail_artifact(@connection_testsuite, nil)
    @items_to_remove_testsuite.push(suite)

    # 2 - Create a Section
    extra_fields = {'suite_id' => suite_id}
    section,section_id = create_testrail_artifact(@connection_testsection, extra_fields)
    @items_to_remove_testsection.push(section)
    
    # 3 - Create a TestCase
    extra_fields = {'section_id' => section_id}
    testcase,testcase_id = create_testrail_artifact(@connection_tmp4, extra_fields)
    @items_to_remove_testcase.push(testcase)
     
    # 4 - Update the external_end_user_id_field
    new_fmtid = 'DE1234'
    @connection_tmp4.update_external_id_fields(testcase, nil, new_fmtid, nil)
     
    # 5 - Verify it was placed properly
    found_item = @connection_tmp4.find(testcase)
    sys_name = 'custom_' + TestConfig::TR_EXTERNAL_EU_ID_FIELD.downcase
    expect(found_item[sys_name]).to eq(new_fmtid)
  end

  it "(5), should update a existing case using update_internal" do
    # 1 - Create a Suite
    suite,suite_id = create_testrail_artifact(@connection_testsuite, nil)
    @items_to_remove_testsuite.push(suite)

    # 2 - Create a Section
    extra_fields = {'suite_id' => suite_id}
    section,section_id = create_testrail_artifact(@connection_testsection, extra_fields)
    @items_to_remove_testsection.push(section)
    
    # 3 - Create a TestCase
    extra_fields = {'section_id' => section_id}
    testcase,testcase_id = create_testrail_artifact(@connection_testcase, extra_fields)
    @items_to_remove_testcase.push(testcase)
    
    # 4 - Update the subject field
    title = testcase['title'] + " ... and more title"
    @connection_testcase.update_internal(testcase, {'title' => "#{title}"})
    
    # 5 - Verify it was placed properly
    found_item = @connection_testcase.find(testcase)
    expect(found_item['title']).to eq(title)
  end
  
  it "(6), should update two fields on a existing case" do
    # 1 - Create a Suite
    suite,suite_id = create_testrail_artifact(@connection_testsuite, nil)
    @items_to_remove_testsuite.push(suite)

    # 2 - Create a Section
    extra_fields = {'suite_id' => suite_id}
    section,section_id = create_testrail_artifact(@connection_testsection, extra_fields)
    @items_to_remove_testsection.push(section)
    
    # 3 - Create a TestCase
    extra_fields = {'section_id' => section_id}
    testcase,testcase_id = create_testrail_artifact(@connection_testcase, extra_fields)
    @items_to_remove_testcase.push(testcase)
    
    # 4 - Update the title & description fields
    title    = testcase['title'] + " ... and more title"
    estimate = '1h 2m 3s'
    @connection_testcase.update_internal(testcase, {'title' => "#{title}", 'estimate' => "#{estimate}"})

    # 5 - Verify the fields were changed
    found_item = @connection_testcase.find(testcase)
    expect(found_item['title']).to eq(title)
    expect(found_item['estimate']).to eq(estimate)
  end
  
 end
