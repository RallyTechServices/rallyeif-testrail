Date: 20-July-2015

How to run a simple demo with TestRail connector.

01) To run the TestRail Connector:

    a) In TestRail:
        - Create new TestRail project
        - Add two TestCases
        - Add a TestPlan (it will be called Rxxx)
        - Add a TestRun
            - Select the 2 TestCases
            - Go to TestRun
            - Mark TestCases as Passed and Failed

    b) In Rally:
        - Create a User Story
        - Then set ExternalID field to Rxxx from above

    c) Running connector:
        - Fix config file to match environment
        - Run the Connector with cfg-file1 (./configs/JP-VCE-demo-testcase.xml):
            - It should copy two TestCases to Rally
            - Look in Rally:
                - under Quality>>TestCases, you should see two new TestCases
                - under Track>>Iteration Status>>Unscheduled, you should the two
                  TestCases under the UserStory you created earlier
            - Look in TestRail:
                - the two TestCases should have the fields RallyObjectID and
                  RallyFormattedID populated.
        - Run the Connector with cfg-file2 (./configs/JP-VCE-demo-testresult.xml):
            - It should copy two TestCaseResults to Rally
            - Look in Rally:
                - under Quality>>TestCases>>(expand the +), you should see that
                  the two TestCases each now have a TestCaseResult associated
                  with them.
                - under Track>>Iteration Status>>Unscheduled, you should see a
                  new TestSet
                - expand the Rally TestSet (click on triangle)
                    - you should the two TestCases under the TestSet
            - Look in TestRail:
                - nothing should change


02) To re-run the TestRail Connector:

    a) In TestRail:
        - Go to TestCases:
            - Clear RallyObjectID and RallyFormattedID on the two TestCases

    b) In Rally:
        - Under Track>>Iteration Status>>Unscheduled:
            - delete the TestSet that was created
         - Under Quality>>TestCases:
            - delete the two TestCaseResults
            - delete the two testCases

    c) You should be able to re-run the connector.

[the end]
