require File.dirname(__FILE__) + '/../spec_helpers/spec_helper'
require File.dirname(__FILE__) + '/../spec_helpers/testrail_spec_helper'

include TestRailSpecHelper
include YetiTestUtils

describe "When trying to connect to testrail for test case results" do
  
  it "should succeed in validating test case result artifact type" do
    tcr_config = YetiTestUtils::modify_config_data(
        TestRailSpecHelper::TESTRAIL_STATIC_CONFIG, #1 CONFIG  - The config file to be augmented
        "TestRailConnection",                       #2 SECTION - XML element of CONFIG to be augmented
        "ArtifactType",                                     #3 NEWTAG  - New tag name in reference to REFTAG
        'TestResult',                               #4 VALUE   - New value to put into NEWTAG
        "replace",                                  #5 ACTION  - [before, after, replace, delete]
        "ArtifactType")                                     #6 REFTAG  - Existing tag in SECTION
    connection = testrail_connect(tcr_config)
    expect(connection.user).to eq(TestConfig::TR_USER)
    expect(connection.validate).to be(true)

  end

end