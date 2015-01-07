module TestConfig

  # MAKE YOUR OWN VERSION OF THIS and name it 
  # test_configuration_helper.rb
  #
  # DO NOT CHECK IT IN
  
  #
  #
  # rally connection information
  RALLY_USER      = "someone@somewhere.com"
  RALLY_USER_OID  = "123456"  #for slow testing of UserTransformer
  RALLY_PASSWORD  = "secret"
  RALLY_URL       = "demo01.rallydev.com"
  RALLY_WORKSPACE = "Integrations"
  
  # rally configurable information for testing
  # choose a place where we can put lots and lots and lots of 
  # defects and stories.  You can always close these projects later
  RALLY_EXTERNAL_ID_FIELD = "ExternalID"
  RALLY_PROJECT_1         = "Payment Team"
  RALLY_PROJECT_1_OID     = "723161" # Object ID of Project_1
  RALLY_PROJECT_2         = "Shopping Team"
  
  # rally projects in a hierarchical tree for hierarchy tests
  RALLY_PROJECT_HIERARCHICAL_PARENT     = "Online Store"
  RALLY_PROJECT_HIERARCHICAL_CHILD      = "Reseller Site"
  RALLY_PROJECT_HIERARCHICAL_GRANDCHILD = "Reseller Portal Team"
  
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
  TR_URL      = "https://tsrally.testrail.com"
  TR_USER     = "technical-services@rallydev.com"
  TR_PASSWORD = ""
  TR_PROJECT  = ""
  
  # Required custom fields (must be created before running these tests):
  TR_EXTERNAL_ID_FIELD    = ""                  # type = Integer
  TR_EXTERNAL_EU_ID_FIELD = ""                  # type = String
  TR_CROSSLINK_FIELD      = ""                  # type = Url (link)
  # To create a custom field in TestRail:
  # 1) Login
  # 2) Click 'Administration' (top right)
  # 3) Click 'Customizations'
  # 4) Click 'Add Field' under 'Test Case Field'
  # 5) Enter values for 'Label', 'Description', System Name', and 'Type'
  # 6) Click 'Add Projects & Options'
  # 7) Click 'Selected Projects' tab in pop-up; select 'These options apply to all projects'
  # 8) Click 'OK'
  # 9) Click 'Add Field'

  TR_ARTIFACT_TYPE        = "TestCase"          #
  TR_ID_FIELD             = "id"                # type = Integer

end