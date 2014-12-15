require File.dirname(__FILE__) + '/../spec_helpers/spec_helper'
require File.dirname(__FILE__) + '/../spec_helpers/sf_spec_helper'

include SalesForceSpecHelper
include YetiTestUtils

describe "Given configuration in the SalesForceConnection section," do
  before(:all) do
    #
  end
   
  it "should successfully load basic config settings " do
    salesforce_connection = salesforce_connect(SalesForceSpecHelper::SALESFORCE_STATIC_CONFIG)
    salesforce_connection.artifact_type.should == TestConfig::SF_ARTIFACT_TYPE.downcase.to_sym
  end
  
  it "should successfully validate a basic config file " do
    salesforce_connection = salesforce_connect(SalesForceSpecHelper::SALESFORCE_STATIC_CONFIG)
    salesforce_connection.validate.should be_true
  end
  
  it "should reject missing required fields" do
    expect { salesforce_connect(SalesForceSpecHelper::SALESFORCE_MISSING_ARTIFACT_CONFIG) }.to raise_error(/ArtifactType must not be null/)
    expect { salesforce_connect(SalesForceSpecHelper::SALESFORCE_MISSING_URL_CONFIG) }.to raise_error(/Url must not be null/)
    expect { salesforce_connect(SalesForceSpecHelper::SALESFORCE_MISSING_CONSUMERKEY_CONFIG) }.to raise_error(/ConsumerKey must not be null/)
    expect { salesforce_connect(SalesForceSpecHelper::SALESFORCE_MISSING_CONSUMERSECRET_CONFIG) }.to raise_error(/ConsumerSecret must not be null/)
  end
  
  it "should reject invalid artifact types" do
    fred_artifact_config = YetiTestUtils::modify_config_data(
                            SalesForceSpecHelper::SALESFORCE_STATIC_CONFIG,           #1 CONFIG  - The config file to be augmented
                            "SalesForceConnection",                                   #2 SECTION - XML element of CONFIG to be augmented
                            "ArtifactType",                                           #3 NEWTAG  - New tag name in reference to REFTAG
                            "Fred",                                                   #4 VALUE   - New value to put into NEWTAG
                            "replace",                                                #5 ACTION  - [before, after, replace, delete]
                            "ArtifactType")                                           #6 REFTAG  - Existing tag in SECTION
    expect { salesforce_connect(fred_artifact_config) }.to raise_error(/Could not find <ArtifactType>/)
  end
  
  it "should be OK with tags named <ExternalEndUserIDField>, <CrosslinkUrlField> and <IDField>" do
    # Checking <ExternalEndUserIDField>
    salesforce_connection = salesforce_connect(SalesForceSpecHelper::SALESFORCE_EXTERNAL_FIELDS_CONFIG)
    salesforce_connection.external_end_user_id_field.should == TestConfig::SF_EXTERNAL_EU_ID_FIELD.to_sym
    salesforce_connection.external_item_link_field.should == TestConfig::SF_CROSSLINK_FIELD.to_sym
    salesforce_connection.id_field.should == TestConfig::SF_ID_FIELD.to_sym
  end
  
  it "should be OK with missing <ExternalEndUserIDField>, <CrosslinkUrlField> and <IDField>" do
    # Checking <ExternalEndUserIDField>
    salesforce_connection = salesforce_connect(SalesForceSpecHelper::SALESFORCE_STATIC_CONFIG)
    salesforce_connection.external_end_user_id_field.should be_nil
    salesforce_connection.external_item_link_field.should be_nil
    salesforce_connection.id_field.should be_nil
  end
  
    
  #
  # SOQL query language tests.
  #
  it "should read SOQL with 'WHERE' in the clause" do
    salesforce_connection = salesforce_connect(SalesForceSpecHelper::SALESFORCE_SOQL_COPY_CONFIG)
    salesforce_connection.soql_copy.should == "Name like SF%"
  end
  
  it "should read SOQL with 'WHERE' not in the clause" do
    query = "Name like SF%"
    wl_artifact_config = YetiTestUtils::modify_config_data(
                            SalesForceSpecHelper::SALESFORCE_SOQL_COPY_CONFIG,        #1 CONFIG  - The config file to be augmented
                            "SalesForceConnection",                                   #2 SECTION - XML element of CONFIG to be augmented
                            "SOQLCopySelector",                                       #3 NEWTAG  - New tag name in reference to REFTAG
                            query,                                                    #4 VALUE   - New value to put into NEWTAG
                            "replace",                                                #5 ACTION  - [before, after, replace, delete]
                            "SOQLCopySelector")                                       #6 REFTAG  - Existing tag in SECTION
    salesforce_connection = salesforce_connect(wl_artifact_config)
    salesforce_connection.soql_copy.should == query
  end
  
  it "should read SOQL with 'WHERE' not in the clause for 'Subject' field" do
    query_given = "Subject like SF%"
    query_fixed = "Subject like SF%"
    wl_artifact_config = YetiTestUtils::modify_config_data(
                            SalesForceSpecHelper::SALESFORCE_SOQL_COPY_CONFIG,        #1 CONFIG  - The config file to be augmented
                            "SalesForceConnection",                                   #2 SECTION - XML element of CONFIG to be augmented
                            "SOQLCopySelector",                                       #3 NEWTAG  - New tag name in reference to REFTAG
                            query_given,                                              #4 VALUE   - New value to put into NEWTAG
                            "replace",                                                #5 ACTION  - [before, after, replace, delete]
                            "SOQLCopySelector")                                       #6 REFTAG  - Existing tag in SECTION
    salesforce_connection = salesforce_connect(wl_artifact_config)
    salesforce_connection.soql_copy.should == query_fixed
  end  
  
  it "should read SOQL with 'SELECT' in the clause" do
    query_given = "SELECT Id FROM Case WHERE Name like SF%"
    query_fixed = "Name like SF%"
    wl_artifact_config = YetiTestUtils::modify_config_data(
                            SalesForceSpecHelper::SALESFORCE_SOQL_COPY_CONFIG,        #1 CONFIG  - The config file to be augmented
                            "SalesForceConnection",                                   #2 SECTION - XML element of CONFIG to be augmented
                            "SOQLCopySelector",                                       #3 NEWTAG  - New tag name in reference to REFTAG
                            query_given,                                              #4 VALUE   - New value to put into NEWTAG
                            "replace",                                                #5 ACTION  - [before, after, replace, delete]
                            "SOQLCopySelector")                                       #6 REFTAG  - Existing tag in SECTION
    salesforce_connection = salesforce_connect(wl_artifact_config)
    salesforce_connection.soql_copy.should == query_fixed
  end

  it "should read SOQL with 'where' not in the clause" do
    query_given = "where Name like SF%"
    query_fixed = "Name like SF%"
    wl_artifact_config = YetiTestUtils::modify_config_data(
                            SalesForceSpecHelper::SALESFORCE_SOQL_COPY_CONFIG,        #1 CONFIG  - The config file to be augmented
                            "SalesForceConnection",                                   #2 SECTION - XML element of CONFIG to be augmented
                            "SOQLCopySelector",                                       #3 NEWTAG  - New tag name in reference to REFTAG
                            query_given,                                              #4 VALUE   - New value to put into NEWTAG
                            "replace",                                                #5 ACTION  - [before, after, replace, delete]
                            "SOQLCopySelector")                                       #6 REFTAG  - Existing tag in SECTION
    salesforce_connection = salesforce_connect(wl_artifact_config)
    salesforce_connection.soql_copy.should == query_fixed
  end
  
  it "should read SOQL with 'select' in the clause" do
    query_given = "select Id FROM Case where Name like SF%"
    query_fixed = "Name like SF%"
    wl_artifact_config = YetiTestUtils::modify_config_data(
                            SalesForceSpecHelper::SALESFORCE_SOQL_COPY_CONFIG,        #1 CONFIG  - The config file to be augmented
                            "SalesForceConnection",                                   #2 SECTION - XML element of CONFIG to be augmented
                            "SOQLCopySelector",                                       #3 NEWTAG  - New tag name in reference to REFTAG
                            query_given,                                              #4 VALUE   - New value to put into NEWTAG
                            "replace",                                                #5 ACTION  - [before, after, replace, delete]
                            "SOQLCopySelector")                                       #6 REFTAG  - Existing tag in SECTION
    salesforce_connection = salesforce_connect(wl_artifact_config)
    salesforce_connection.soql_copy.should == query_fixed
  end
  
  it "should read SOQL with 'select' in the clause for 'Subject' field" do
    query_given = "select Name FROM Case where Subject like SF%"
    query_fixed = "Subject like SF%"
    wl_artifact_config = YetiTestUtils::modify_config_data(
                            SalesForceSpecHelper::SALESFORCE_SOQL_COPY_CONFIG,        #1 CONFIG  - The config file to be augmented
                            "SalesForceConnection",                                   #2 SECTION - XML element of CONFIG to be augmented
                            "SOQLCopySelector",                                       #3 NEWTAG  - New tag name in reference to REFTAG
                            query_given,                                              #4 VALUE   - New value to put into NEWTAG
                            "replace",                                                #5 ACTION  - [before, after, replace, delete]
                            "SOQLCopySelector")                                       #6 REFTAG  - Existing tag in SECTION
    salesforce_connection = salesforce_connect(wl_artifact_config)
    salesforce_connection.soql_copy.should == query_fixed
  end
  
  it "should be OK to have 'WHERE' in the WHERE clause(1)" do
    query_given = "select Id FROM Case where Name like WHERE%"
    query_fixed = "Name like WHERE%"
    wl_artifact_config = YetiTestUtils::modify_config_data(
                            SalesForceSpecHelper::SALESFORCE_SOQL_COPY_CONFIG,        #1 CONFIG  - The config file to be augmented
                            "SalesForceConnection",                                   #2 SECTION - XML element of CONFIG to be augmented
                            "SOQLCopySelector",                                       #3 NEWTAG  - New tag name in reference to REFTAG
                            query_given,                                              #4 VALUE   - New value to put into NEWTAG
                            "replace",                                                #5 ACTION  - [before, after, replace, delete]
                            "SOQLCopySelector")                                       #6 REFTAG  - Existing tag in SECTION
    salesforce_connection = salesforce_connect(wl_artifact_config)
    salesforce_connection.soql_copy.should == query_fixed
  end
  
  it "should be OK to have 'WHERE' in the WHERE clause(2)" do
    query_given = "Name like WHERE %"
    query_fixed = "Name like WHERE %"
    wl_artifact_config = YetiTestUtils::modify_config_data(
                            SalesForceSpecHelper::SALESFORCE_SOQL_COPY_CONFIG,        #1 CONFIG  - The config file to be augmented
                            "SalesForceConnection",                                   #2 SECTION - XML element of CONFIG to be augmented
                            "SOQLCopySelector",                                       #3 NEWTAG  - New tag name in reference to REFTAG
                            query_given,                                              #4 VALUE   - New value to put into NEWTAG
                            "replace",                                                #5 ACTION  - [before, after, replace, delete]
                            "SOQLCopySelector")                                       #6 REFTAG  - Existing tag in SECTION
    salesforce_connection = salesforce_connect(wl_artifact_config)
    salesforce_connection.soql_copy.should == query_fixed
  end
    
  it "should be OK to have 'AND' in the clause" do
    query_given = "where Description like WHERE% and Subject like SELECT%"
    query_fixed = "Description like WHERE% and Subject like SELECT%"
    wl_artifact_config = YetiTestUtils::modify_config_data(
                            SalesForceSpecHelper::SALESFORCE_SOQL_COPY_CONFIG,        #1 CONFIG  - The config file to be augmented
                            "SalesForceConnection",                                   #2 SECTION - XML element of CONFIG to be augmented
                            "SOQLCopySelector",                                       #3 NEWTAG  - New tag name in reference to REFTAG
                            query_given,                                              #4 VALUE   - New value to put into NEWTAG
                            "replace",                                                #5 ACTION  - [before, after, replace, delete]
                            "SOQLCopySelector")                                       #6 REFTAG  - Existing tag in SECTION
    salesforce_connection = salesforce_connect(wl_artifact_config)
    salesforce_connection.soql_copy.should == query_fixed
  end
    
end