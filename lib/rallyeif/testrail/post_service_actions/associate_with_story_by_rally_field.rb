# Copyright 2001-2015 Rally Software Development Corp. All Rights Reserved.

module RallyEIF
  module WRK
    module PostServiceActions

      # expect to see a TestRail TestPlan ID in a field on a Rally Story
      class AssociateWithStoryByRallyField < PostServiceAction

        def setup(action_config, rally_conn, other_conn)
          super(action_config, rally_conn, other_conn)
          if other_conn.artifact_type != :testcase
            msg = "AssociateWithStoryByRallyField will only work with the TestCase Artifact in TestRail"
            raise UnrecoverableException.new(msg, self)
          end
          if (rally_conn.artifact_type != :testcase)
            msg = "AssociateWithStoryByRallyField will only work with the TestCase Artifact in Rally"
            raise UnrecoverableException.new(msg, self)
          end
          
          if (other_conn.rally_story_field_for_plan_id.nil?)
            msg = "AssociateWithStoryByRallyField requires that the TestRailConnection section have an entry for <RallyStoryFieldForPlanID>"
            raise UnrecoverableException.new(msg, self)
          end
        end

        def post_copy_to_rally_action(testcase_list)
          process_parents(testcase_list)
        end

        def post_update_to_rally_action(testcase_list)
          process_parents(testcase_list)
        end

        def find_rally_stories_with_plan_ids()
          plan_id_field_on_stories = @other_connection.rally_story_field_for_plan_id
          RallyLogger.info(self, "Find Rally Stories with a value in '#{plan_id_field_on_stories}'")
          @rally = @rally_connection.rally
         
          begin
            query = RallyAPI::RallyQuery.new()
            query.type       = 'hierarchicalrequirement'
            query.workspace  = @rally_connection.workspace
            #query.fetch      = "true"
            query.fetch      = "FormattedID,Name,#{plan_id_field_on_stories}"
            query.limit      = 1000
  
            base_string = "(#{plan_id_field_on_stories} != \"\")"
#            base_string = "(#{plan_id_field_on_stories} = null)" if @rally_connection.rally_data_type(@external_id_field) == 'INTEGER'
            projects_q = []
            @rally_connection.projects.each { |prj| projects_q << "Project.Name = \"#{prj["Name"]}\"" }
            #builds big or part of query with projects
            prj_string = query.build_query_segment(projects_q, "OR")
            base_query = query.add_and(base_string, prj_string)
  
            if @rally_connection.copy_selectors.length > 0
              @rally_connection..each do |cs|
                addition = "(#{cs.field} #{cs.relation} \"#{cs.value}\")"
                base_query = query.add_and(base_query, addition)
              end
            end
  
            query.query_string = base_query
            #query.query_string = base_string
            RallyLogger.debug(self, "Rally using query: '#{query.query_string}'")
  
            query_result = @rally.find(query)
  
          rescue Exception => ex
            raise UnrecoverableException.copy(ex, self)
          end
  
          RallyLogger.info(self, "  Found '#{query_result.total_result_count}' Stories in Rally")
          return query_result
        end
        
        def process_parents(tr_testcase_list)
          RallyLogger.debug(self, "Running post process to associate test cases to stories in Rally...")
          # test plans will have a story FormattedID in the name to indicate they go to the story
          plans = @other_connection.find_test_plans()
          stories = find_rally_stories_with_plan_ids()
          
          plan_id_field_on_stories = @other_connection.rally_story_field_for_plan_id
          
          plan_hash = {} # key will be plan id
          case_parents = {} # key will be test case id
            
          plans.each do |plan|
            plan_hash["R#{plan['id']}"] = plan
          end
          
          # RallyLogger.debug(self, "Plans #{plans}\n #{plan_hash}")
          stories.each do |story|
            plan = plan_hash["R#{story[plan_id_field_on_stories]}"] || plan_hash["#{story[plan_id_field_on_stories]}"]
            if ( !plan.nil?)
              #RallyLogger.debug(self, "Found test plan #{plan}, #{plan.keys}")
              RallyLogger.debug(self, "Found test plan '#{plan['name']}'")
              
              plan['tests'].flatten.each do |test|
                case_parents[test['case_id']] = story
              end
            else
              RallyLogger.debug(self, "Did not find a test plan for story '#{story.FormattedID}', test plan ID '#{story[plan_id_field_on_stories]}'")
            end
          end
          
          case_parents.keys.each do |case_id|
            RallyLogger.debug(self, "Associating Test Rail Test Case '#{case_id}' with Rally Story '#{case_parents[case_id].FormattedID}'")
            story = case_parents[case_id]
            begin
              rally_testcase = @rally_connection.find_by_external_id(case_id)
            rescue Exception => ex
              #
            end
            if !rally_testcase.nil?
              RallyLogger.debug(self, "Linking Rally Test Case '#{rally_testcase['FormattedID']}' to Story '#{story['FormattedID']}'")
              @rally_connection.update(rally_testcase, { "WorkProduct" => story })
            else
              RallyLogger.debug(self, "There is not a Rally Test Case for Test Rail Test Case '#{case_id}"'')
            end
          end
          RallyLogger.debug(self, "Completed running post process to associate test cases to stories in Rally.")
        end

      end

    end
  end
end
