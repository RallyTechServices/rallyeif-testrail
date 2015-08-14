# Copyright 2001-2015 Rally Software Development Corp. All Rights Reserved.

module RallyEIF
  module WRK
    module PostServiceActions

      class CreateTestSets < PostServiceAction

        def setup(action_config, rally_conn, other_conn)
          super(action_config, rally_conn, other_conn)
          if other_conn.artifact_type != :testresult
            msg = "CreateTestSets will only work with the TestResult Artifact in TestRail"
            raise UnrecoverableException.new(msg, self)
          end
          if (rally_conn.artifact_type != :testcaseresult)
            msg = "CreateTestSets will only work with the TestCaseResult Artifact in Rally"
            raise UnrecoverableException.new(msg, self)
          end
        end

        def post_copy_to_rally_action(item_list)
          process_results(item_list)
        end

        def post_update_to_rally_action(item_list)
          process_results(item_list)
        end

        def find_rally_test_case_by_oid(oid)
          
          begin
            query = RallyAPI::RallyQuery.new()
            query.type       = 'testcase'
            query.workspace  = @rally_connection.workspace
            #query.fetch      = "true"
            query.fetch      = "FormattedID,Name,Iteration,Project,WorkProduct,ObjectID"
            query.limit      = 1
  
            base_string = "( ObjectID = #{oid} )"
  
            query.query_string = base_string
            RallyLogger.debug(self, "Query Rally for '#{query.type}' using: #{query.query_string}")
            query_result = @rally_connection.rally.find(query)
  
            RallyLogger.debug(self, "\tquery for '#{query.type}' returned '#{query_result.length}'; using first")
          rescue Exception => ex
            raise UnrecoverableException.copy(ex, self)
          end
          
          return query_result.first
        end
        
        def find_rally_test_set_by_name(name)
          begin
            query = RallyAPI::RallyQuery.new()
            query.type       = 'testset'
            query.workspace  = @rally_connection.workspace
            query.fetch      = "FormattedID,Name,Iteration,Project,ObjectID"
            query.limit      = 1
  
            base_string = "( Name contains \"#{name}\" )"
  
            query.query_string = base_string
            RallyLogger.debug(self, "Query Rally for '#{query.type}' using: #{query.query_string}")
            
            query_result = @rally_connection.rally.find(query)
            
            RallyLogger.debug(self, "\tquery for '#{query.type}' returned '#{query_result.length}'; using first")
          rescue Exception => ex
            raise UnrecoverableException.copy(ex, self)
          end
          
          return query_result.first
        end
        
        def create_rally_test_set(name)
          RallyLogger.debug(self, "Creating a TestSet named: '#{name}'")
          new_test_set = nil
          ts = { "Name" => name }
          new_test_set = @rally_connection.rally.create('testset',ts)
          return new_test_set
        end
        
        def add_testcase_to_test_set(rally_test_case,rally_test_set)
          RallyLogger.info(self, "Adding '#{rally_test_case}' to '#{rally_test_set}'")
          
          test_set = @rally_connection.rally.read("testset", rally_test_set['ObjectID'])
          
          associated_test_cases = test_set['TestCases'] || []
          associated_test_cases = associated_test_cases.push(rally_test_case)
          
          refs = []
            
          associated_test_cases.each do |tc|
            refs.push({"_ref"=> tc['_ref']})
          end

          fields = { "TestCases" => refs }
          rally_test_set.update(fields)
        end
        
        def process_results(tr_testresults_list)
          RallyLogger.debug(self, "Running post process to associate test runs to test sets in Rally...")
         
          runs,run_ids = @other_connection.find_test_runs()
          
          runs.each do |run|
            run_name = "#{run['id']}: #{run['name']} #{run['config']}"
            
            rally_test_set = nil

            # RallyLogger.debug(self, "--Test: #{test}")
            # 1 - create testset
            # 2 - find testplan id for this testrun
            # 3 - find story in rally with the testplan id
            # 4 - get rally story proj/iter
            # 5 - add to testset
            # 6 - ???

            # 1 - create testset
            rally_test_set = find_rally_test_set_by_name("#{run['id']}:")
            if rally_test_set.nil?
              rally_test_set = create_rally_test_set(run_name)
            end
            
            
            if !rally_test_set.nil?
              # 2 - find testplan id for this testrun
              plan_id = run['plan_id']
              
              # 3 - find story in rally with the testplan id
              story = find_rally_story_with_plan_id(plan_id)
              if story.total_result_count > 0
                
                # 4 - get rally story proj/iter
#require 'pry-debugger';binding.pry
                project = story.first.Project
                iteration = story.first.Iteration
                
                # 5 - add to testset
                #fields = {
                #  "Project"   => {'_ref'=> project['_ref']},
                #  "Iteration" => {'_ref'=> iteration['_ref']}
                #}
#####################################
                fields = {'Project' => {'_ref'=> project['_ref']}}
                if !iteration.nil?
                  fields['Iteration'] =  {'_ref'=> iteration['_ref']}
                end
#####################################
                rally_test_set.update(fields)
              else
                #RallyLogger.debug(self, "Found no stories with a plan_id value")
              end
            end
          end
          
          RallyLogger.info(self,"Associate TestResult with the TestSet")
          tr_testresults_list.each do |testresult|
            #RallyLogger.debug(self,"TestRail testresult: '#{testresult}'")
            RallyLogger.debug(self,"TestRail testresult: id='#{testresult['id']}'  test_id='#{testresult['status_id']}'  status_id='#{testresult['status_id']}'")
            RallyLogger.debug(self,"\t    _test: id='#{testresult['_test']['id']}'  case_id='#{testresult['_test']['case_id']}'  run_id='#{testresult['_test']['run_id']}'")
            RallyLogger.debug(self,"\t_testcase: id='#{testresult['_testcase']['id']}'  formattedid='#{testresult['_testcase']['custom_rallyformattedid']}'")
            rally_test_set = find_rally_test_set_by_name("#{testresult['_test']['run_id']}:")
            if rally_test_set.nil?
              RallyLogger.debug(self,"test: <no test set found in Rally>")
            else
              RallyLogger.debug(self,"test: '#{testresult['_test']['run_id']}'")
            end
            rally_result = @rally_connection.find_result_with_build(testresult['id'])
            if !rally_result.nil? && !rally_test_set.nil?
              fields = {"TestSet"=>{'_ref'=>rally_test_set['_ref']}}
              rally_result.update(fields)
            else
              RallyLogger.info(self, "No result found in Rally: '#{testresult['id']}'")
            end
          end
          
          RallyLogger.debug(self, "Completed running post process to associate test runs to test sets in Rally.")
        end

        def find_rally_story_with_plan_id(plan_id)
          plan_id_field_on_stories = @other_connection.rally_story_field_for_plan_id
          RallyLogger.info(self, "Find Rally Story with '#{plan_id}' in '#{plan_id_field_on_stories}'")
          @rally = @rally_connection.rally
          
          begin
            query            = RallyAPI::RallyQuery.new()
            query.type       = 'hierarchicalrequirement'
            query.workspace  = @rally_connection.workspace
            query.fetch      = "FormattedID,Name,Project,Iteration,#{plan_id_field_on_stories}"
            query.limit      = 1 # We want only one
            query.page_size  = 1 # Be sure we do get more in background
    
            base_query = "(#{plan_id_field_on_stories} != \"\")"
            ##projects_q = []
            ##@rally_connection.projects.each { |prj| projects_q << "Project.Name = \"#{prj["Name"]}\"" }
            #builds big or part of query with projects
            ##prj_string = query.build_query_segment(projects_q, "OR")
            ##base_query = query.add_and(base_string, prj_string)
     
            if @rally_connection.copy_selectors.length > 0
              @rally_connection.each do |cs|
                addition = "(#{cs.field} #{cs.relation} \"#{cs.value}\")"
                base_query = query.add_and(base_query, addition)
              end
            end
     
            query.query_string = base_query
            RallyLogger.debug(self, "Rally using query: '#{query.query_string}'")
            query_result = @rally.find(query)
     
          rescue Exception => ex
            raise UnrecoverableException.copy(ex, self)
          end
     
          RallyLogger.info(self, "  Found '#{query_result.total_result_count}' Stories in Rally")
          return query_result
        end # of 'def find_rally_story_with_plan_id(plan_id)'
        
      end
    end
  end
end
