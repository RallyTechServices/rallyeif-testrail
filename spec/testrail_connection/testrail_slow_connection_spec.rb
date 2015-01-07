require File.dirname(__FILE__) + '/../spec_helpers/spec_helper'
require File.dirname(__FILE__) + '/../spec_helpers/testrail_spec_helper'

include TestRailSpecHelper
include YetiTestUtils

describe "When trying to connect to testrail" do
  before(:all) do
    @auth_err = "Authentication failed: invalid or missing user/password or session cookie."
  end
  
  it "(1), should succeed in retreiving information for config file user" do
    # TestRail User object:
    #   "email"     : "alexis@example.com",
    #   "id"        : 1,
    #   "is_active" : true,
    #   "name"      : "Alexis Gonzalez"
    connection = testrail_connect(TestRailSpecHelper::TESTRAIL_STATIC_CONFIG)
    expect(connection.user).to eq(TestConfig::TR_USER)
    expect(connection.password).to eq(TestConfig::TR_PASSWORD)
  end

  it "(2), should fail when given a bad User name for TestRail" do
    bad_username = "IamABadUserName" + rand(10..99).to_s  # So we don't hit max retry count
    bad_username_config = YetiTestUtils::modify_config_data(
                            TestRailSpecHelper::TESTRAIL_STATIC_CONFIG, #1 CONFIG  - The config file to be augmented
                            "TestRailConnection",                       #2 SECTION - XML element of CONFIG to be augmented
                            "User",                                     #3 NEWTAG  - New tag name in reference to REFTAG
                            bad_username,                               #4 VALUE   - New value to put into NEWTAG
                            "replace",                                  #5 ACTION  - [before, after, replace, delete]
                            "User")                                     #6 REFTAG  - Existing tag in SECTION
    expect { testrail_connect(bad_username_config)}.to raise_error(/#{@auth_err}/)
  end

  it "(3), should fail when given a bad User password for TestRail" do
    bad_password_config = YetiTestUtils::modify_config_data(
                            TestRailSpecHelper::TESTRAIL_STATIC_CONFIG, #1 CONFIG  - The config file to be augmented
                            "TestRailConnection",                       #2 SECTION - XML element of CONFIG to be augmented
                            "Password",                                 #3 NEWTAG  - New tag name in reference to REFTAG
                            "IamABadPassword",                          #4 VALUE   - New value to put into NEWTAG
                            "replace",                                  #5 ACTION  - [before, after, replace, delete]
                            "Password")                                 #6 REFTAG  - Existing tag in SECTION
    expect { testrail_connect(bad_password_config)}.to raise_error(/#{@auth_err}/)
  end

end