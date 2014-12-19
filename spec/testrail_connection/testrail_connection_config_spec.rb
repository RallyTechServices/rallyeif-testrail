require File.dirname(__FILE__) + '/../spec_helpers/spec_helper'
require File.dirname(__FILE__) + '/../spec_helpers/testrail_spec_helper'

include TestRailSpecHelper
include YetiTestUtils

describe "Given configuration in the TestRail section" do
  before(:all) do
    #
  end
   
  it "(1), should successfully load basic config settings " do
    connection = testrail_connect(TestRailSpecHelper::TESTRAIL_STATIC_CONFIG)
    connection.artifact_type.should == TestConfig::TR_ARTIFACT_TYPE.downcase.to_sym
  end
  
  it "(2), should successfully validate a basic config file " do
    connection = testrail_connect(TestRailSpecHelper::TESTRAIL_STATIC_CONFIG)
require 'debugger';debugger
    connection.validate.should be_true
  end
  
  it "(3), should reject missing required fields" do
    expect { testrail_connect(TestRailSpecHelper::TESTRAIL_MISSING_ARTIFACT_CONFIG) }.to raise_error(/ArtifactType must not be null/)
    expect { testrail_connect(TestRailSpecHelper::TESTRAIL_MISSING_URL_CONFIG) }.to raise_error(/Url must not be null/)
  end
  
  it "(4), should reject invalid artifact types" do
    fred_artifact_config = YetiTestUtils::modify_config_data(
                            TestRailSpecHelper::TESTRAIL_STATIC_CONFIG,               #1 CONFIG  - The config file to be augmented
                            "TestRailConnection",                                     #2 SECTION - XML element of CONFIG to be augmented
                            "ArtifactType",                                           #3 NEWTAG  - New tag name in reference to REFTAG
                            "Fred",                                                   #4 VALUE   - New value to put into NEWTAG
                            "replace",                                                #5 ACTION  - [before, after, replace, delete]
                            "ArtifactType")                                           #6 REFTAG  - Existing tag in SECTION
    expect { testrail_connect(fred_artifact_config) }.to raise_error(/Could not find <ArtifactType>/)
  end
  
  it "(5), should be OK with tags named <ExternalEndUserIDField>, <CrosslinkUrlField> and <IDField>" do
    # Checking <ExternalEndUserIDField>
    connection = testrail_connect(TestRailSpecHelper::TESTRAIL_EXTERNAL_FIELDS_CONFIG)
    connection.external_end_user_id_field.should == TestConfig::TR_EXTERNAL_EU_ID_FIELD.to_sym
    connection.external_item_link_field.should == TestConfig::TR_CROSSLINK_FIELD.to_sym
    connection.id_field.should == TestConfig::TR_ID_FIELD.to_sym
  end
  
  it "(6), should be OK with missing <ExternalEndUserIDField>, <CrosslinkUrlField> and <IDField>" do
    # Checking <ExternalEndUserIDField>
    connection = testrail_connect(TestRailSpecHelper::TESTRAIL_STATIC_CONFIG)
    connection.external_end_user_id_field.should be_nil
    connection.external_item_link_field.should be_nil
    connection.id_field.should be_nil
  end
   
end