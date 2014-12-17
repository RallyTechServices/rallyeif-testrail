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
  
  # TestRail connection information
  TR_URL      = "https://tsrally.testrail.com"
  TR_USER     = "technical-services@rallydev.com"
  TR_PASSWORD = ""
  
  # To create a custom field in TestRail:
  # Click on 'Setup' (near top right), 'Build' (left column), 'Customize Cases', 'Fields',
  # then scroll down to "Case Custom Fields & Relationships", click 'New'...
  # (note in config file they must end with "__c")
  TR_EXTERNAL_ID_FIELD    = "RallyObjectID__c"
  TR_EXTERNAL_EU_ID_FIELD = "RallyFormattedID__c"
  TR_ID_FIELD             = "CaseNumber"
  TR_CROSSLINK_FIELD      = "RallyURL__c"
  TR_ARTIFACT_TYPE        = "Case"

end