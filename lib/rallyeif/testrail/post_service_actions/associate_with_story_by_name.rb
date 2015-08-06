# Copyright 2001-2015 Rally Software Development Corp. All Rights Reserved.

module RallyEIF
  module WRK
    module PostServiceActions

      class AssociateWithStoryByName < PostServiceAction

        def setup(action_config, rally_conn, other_conn)
          super(action_config, rally_conn, other_conn)
          if other_conn.artifact_type != :testcase
            msg = "AssociateWithStoryByName will only work with the TestCase Artifact in TestRail"
            raise UnrecoverableException.new(msg, self)
          end
          if (rally_conn.artifact_type != :testcase)
            msg = "AssociateWithStoryByName will only work with the TestCase Artifact in Rally"
            raise UnrecoverableException.new(msg, self)
          end
        end

        def post_copy_to_rally_action(testcase_list)
          process_parents(testcase_list)
        end

        def post_update_to_rally_action(testcase_list)
          process_parents(testcase_list)
        end

        def process_parents(tr_testcase_list)
          RallyLogger.debug(self, "Running post process to associate test cases to stories in Rally...")
          # test plans will have a story FormattedID in the name to indicate they go to the story
          test_plans = @other_connection.find_test_plans()
          case_parents = {} # key will be test case id
          
          test_plans.each do |plan|
            plan_name = plan['name']
            if match = plan_name.match(/([U|S]\d*):/)
              story_formatted_id = match.captures
            end
            
            if !story_formatted_id.nil?
              story = @rally_connection.find_artifact(:hierarchicalrequirement, 'FormattedID', story_formatted_id)

              plan['tests'].flatten.each do |test|
                case_parents[test['case_id']] = story
              end
            end
          end
          
          tr_testcase_list.each do |testcase|
            if !case_parents[testcase['id']].nil?
              RallyLogger.debug( self,  "This case has a parent '#{testcase['id']}': '#{case_parents[testcase['id']]['FormattedID']}'")
              story = case_parents[testcase['id']]
              rally_testcase = @rally_connection.find_by_external_id(testcase['id'])
              if !rally_testcase.nil?
                RallyLogger.debug(self, "Linking Rally Test Case '#{rally_testcase['FormattedID']}' to Story '#{story['FormattedID']}'")
                @rally_connection.update(rally_testcase, { "WorkProduct" => story })
              end
              
            end
          end
          RallyLogger.debug(self, "Completed running post process to associate test cases to stories in Rally.")
        end

      end

    end
  end
end
