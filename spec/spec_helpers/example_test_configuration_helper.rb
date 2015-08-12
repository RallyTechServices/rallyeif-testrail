module TestConfig

  # MAKE YOUR OWN VERSION OF THIS and name it 
  # test_configuration_helper.rb
  #
  # DO NOT CHECK IT IN
  
  #
  #
  # rally connection information
  RALLY_USER      = "someone@somewhere.com"
  RALLY_PASSWORD  = "secret"
  RALLY_URL       = "demo01.rallydev.com"
  RALLY_WORKSPACE = "Integrations"
  
  # rally configurable information for testing
  RALLY_EXTERNAL_ID_FIELD = "ExternalID"
  RALLY_PROJECT_1         = "Payment Team"
  RALLY_PROJECT_2         = "Shopping Team"
  
  # rally projects in a hierarchical tree for hierarchy tests (e.g., post service actions)
  RALLY_PROJECT_HIERARCHICAL_PARENT     = "Online Store"
  RALLY_PROJECT_HIERARCHICAL_PARENT_OID = 722844
  RALLY_PROJECT_HIERARCHICAL_CHILD      = "Reseller Site"
  RALLY_PROJECT_HIERARCHICAL_CHILD_OID  = 723083
  RALLY_PROJECT_HIERARCHICAL_GRANDCHILD = "Reseller Portal Team"
  RALLY_PROJECT_HIERARCHICAL_GRANDCHILD_OID = 723213
  
  # In order to run these test on a new TestRail setup, you'll need:
  # 01) A TestRail Project created.
  # 02) A TestRail Section created.
  # 03) A TestRail Milestone created.
  # 04) Custom fields mentioned at the bottom of this module/file.
  # 05) The API must be enabled for your instance; otherwise you'll get error:
  #     TestRail api returned:TestRail API returned HTTP 403
  #     ("The API is disabled for your installation.
  #       It can be enabled in the administration area in TestRail under:
  #         --> Administration (top right)
  #         --> Site Settings
  #         --> API tab
  #         --> check 'Enable API'
  #         --> Save Settings .")
  
  # The TestRail account to be used for testing:
  TR_URL      = "https://somewhere.testrail.com"
  TR_USER     = "***REMOVED***"
  TR_PASSWORD = ""
  
  test_suite_mode = 3 # Note: Aug-2015 - I have only tested suite-mode 3
  case test_suite_mode
  when 1
    TR_PROJECT  = 'zRakeTest-sm1' # SuiteMode 1
  when 2
    TR_PROJECT  = 'zRakeTest-sm2' # SuiteMode 2
  when 3
    TR_PROJECT  = 'zRakeTest-sm3' # SuiteMode 3
  else
    puts "FATAL Internal Error in test_configuration_helper.rb"
    exit
  end
  
  # Required custom fields (must be created before running these tests):
  TR_EXTERNAL_ID_FIELD    = ""                  # type = Integer
  TR_EXTERNAL_EU_ID_FIELD = ""                  # type = String
  TR_CROSSLINK_FIELD      = ""                  # type = Url (link)
  # To create a custom field in TestRail:
  # 1) Login
  # 2) Click 'Administration' (top right)
  # 3) Click 'Customizations'
  # 4) Click 'Add Field' under 'Test Case Field'
  # 5) Enter values for 'Label', 'Description', 'System Name', and 'Type'
  # 6) Click 'Add Projects & Options'
  # 7) Click 'Selected Projects' tab in pop-up; select 'These options apply to all projects'
  # 8) Click 'OK'
  # 9) Click 'Add Field'

  TR_ARTIFACT_TYPE        = "TestCase"          #
  TR_ID_FIELD             = "id"                # type = Integer
  
  # a field on a Rally STORY that will hold the Id of a TestRail Test Plan so we can associate
  # the test case(s) with a story
  TR_RALLY_FIELD_TO_HOLD_PLAN_ID  = ""
  

end
