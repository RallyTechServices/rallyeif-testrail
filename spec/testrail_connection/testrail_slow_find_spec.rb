require File.dirname(__FILE__) + '/../spec_helpers/spec_helper'
require File.dirname(__FILE__) + '/../spec_helpers/testrail_spec_helper'

include TestRailSpecHelper
include YetiTestUtils

describe "When trying to find TestRail items" do

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

  it "(1), should find new test case without an externalid" do
    # 1 - Find all 'new' TestCases
    all_items_before = @connection_testcase.find_new()

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
    @items_to_remove_testcase.push(testcase)
    
    # 5 - Find all 'new' TestCases again
    @connection_testcase.connect() # must connect to refresh object's list of suites
    all_items_after = @connection_testcase.find_new()

    # 6 - Second find should have more...
    expect(all_items_before.length).to be < (all_items_after.length)
  end
  
  it "(2), should not find test case with an externalid" do
    # 1 - Find all 'new' TestCases
    all_items_before = @connection_testcase.find_new()

    # 2 - Create a Suite
    suite,suite_id = create_testrail_artifact(@connection_testsuite, nil)
    @items_to_remove_testsuite.push(suite)

    # 3 - Create a Section
    extra_fields = {'suite_id' => suite_id}
    section,section_id = create_testrail_artifact(@connection_testsection, extra_fields)
    @items_to_remove_testsection.push(section)

    # 4 - Create a TestCase and give it an external id
    extra_fields = {'section_id' => section_id}
    testcase,testcase_id = create_testrail_artifact(@connection_testcase, extra_fields)
    @items_to_remove_testcase.push(testcase)
    @connection_testcase.update_external_id_fields(testcase, @unique_number, nil, nil)
   
    # 5 - Find all 'new' TestCases again
    @connection_testcase.connect() # must connect to refresh object's list of suites
    all_items_after = @connection_testcase.find_new()
    
    # 6 - Second find should have the same number of items
    expect(all_items_before.length).to eq(all_items_after.length)
  end
  
  it "(3), should not find test case without an externalid" do
    # 1 - Find all 'updated' TestCases (they have an ExternalID)
    time = (Time.now() - 600).utc
    all_items_before = @connection_testcase.find_updates(time)
    
    # 2 - Create a Suite
    suite,suite_id = create_testrail_artifact(@connection_testsuite, nil)
    @items_to_remove_testsuite.push(suite)

    # 3 - Create a Section
    extra_fields = {'suite_id' => suite_id}
    section,section_id = create_testrail_artifact(@connection_testsection, extra_fields)
    @items_to_remove_testsection.push(section)

    # 4 - Create a TestCase and give it an external id
    extra_fields = {'section_id' => section_id}
    testcase,testcase_id = create_testrail_artifact(@connection_testcase, extra_fields)
    @connection_testcase.update_external_id_fields(testcase, @unique_number, nil, nil)
    @items_to_remove_testcase.push(testcase)
   
    # 5 - Find all 'updated' Testcases again
    @connection_testcase.connect() # must connect to refresh object's list of suites
    all_items_after = @connection_testcase.find_updates(time)
    
    #6 - Second find should have more...
    expect(all_items_before.length).to be < (all_items_after.length)
  end

  it "(4), should not find updated test case without an externalid" do
    # 1 - Find all 'updated' TestCases
    time = (Time.now() - 600).utc
    all_items_before = @connection_testcase.find_updates(time)
    
    # 2 - Create a Suite
    suite,suite_id = create_testrail_artifact(@connection_testsuite, nil)
    @items_to_remove_testsuite.push(suite)

    # 3 - Create a Section
    extra_fields = {'suite_id' => suite_id}
    section,section_id = create_testrail_artifact(@connection_testsection, extra_fields)
    @items_to_remove_testsection.push(section)
    
    # 4 - Create TestCase (it will not have a externalID)
    extra_fields = {'section_id' => section_id}
    testcase,testcase_id = create_testrail_artifact(@connection_testcase, extra_fields)
    @items_to_remove_testcase.push(testcase)
   
    # 5 - Find all 'updated' TestCases again (should not find our new item)
    @connection_testcase.connect() # must connect to refresh object's list of suites
    all_items_after = @connection_testcase.find_updates(time)
    
    # 6 - Second find should have more...
    expect(all_items_before.length).to eq(all_items_after.length)
    
    # 7 - Second find should not contain this TestCase
    found_me = false
    all_items_after.each do |found_item|
      if @connection_testcase.get_value(found_item,'id') == testcase_id
        found_me = true
      end
    end
    expect(found_me).to eq(false)
  end

  it "(5), should not find test case with an externalid updated before the timestamp" do
    # 1 - Create a Suite
    suite,suite_id = create_testrail_artifact(@connection_testsuite, nil)
    @items_to_remove_testsuite.push(suite)

    # 2 - Create a Section
    extra_fields = {'suite_id' => suite_id}
    section,section_id = create_testrail_artifact(@connection_testsection, extra_fields)
    @items_to_remove_testsection.push(section)
    
    # 3 - Create a TestCase and give an ExternalID (it will have a timestamp of 'now')
    extra_fields = {'section_id' => section_id}
    testcase,testcase_id = create_testrail_artifact(@connection_testcase, extra_fields)
    @connection_testcase.update_external_id_fields(testcase, @unique_number, nil, nil)
    @items_to_remove_testcase.push(testcase)
   
    # 4 - Pause for 2 seconds, then find all items 'updated' after 'now'
    sleep (2.0)
    time = Time.now().utc
    @connection_testcase.connect() # must connect to refresh object's list of suites
    all_items = @connection_testcase.find_updates(time)

    # 5 - Find should not contain this item
    found_me = false
    all_items.each do |found_item|
      if @connection.get_value(found_item,'id') == id
        found_me = true
      end
    end
    expect(found_me).to eq(false)
  end
  
 end