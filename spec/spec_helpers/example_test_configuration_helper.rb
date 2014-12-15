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
  
  # salesforce connection information
  SF_URL      = "na16.salesforce.com"
  SF_USER     = ""
  SF_PASSWORD = ""
  
  # To create a custom field in Saleforce:
  # Click on 'Setup' (near top right), 'Build' (left column), 'Customize Cases', 'Fields',
  # then scroll down to "Case Custom Fields & Relationships", click 'New'...
  # (note in config file they must end with "__c")
  SF_EXTERNAL_ID_FIELD    = "RallyObjectID__c"
  SF_EXTERNAL_EU_ID_FIELD = "RallyFormattedID__c"
  SF_ID_FIELD             = "CaseNumber"
  SF_CROSSLINK_FIELD      = "RallyURL__c"
  SF_ARTIFACT_TYPE        = "Case"
  
  # In Salesforce under "Setup" (top-right),
  # then in left sidebar, "Build" --> "Create" --> "Apps",
  # then under "Connected Apps" in mid-screen, click on "RallyIntegrations1"
  SF_CONSUMERKEY    = "3MVG.............................................................................vqDX"
  SF_CONSUMERSECRET = "4568...........4805"

end