# Copyright 2001-2015 Rally Software Development Corp. All Rights Reserved.

module RallyEIF
  module WRK
    module PostServiceActions

      class CreateTestSets < PostServiceAction

        @@rally_cached_ts   = Hash.new # cache of Rally TestSets index by ObjectID
        @@rally_cached_tc   = Hash.new #
        @@rally_cached_pid  = Hash.new # key=plan_id; val=user story
        
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
        
        # Get custom field system name
        def cfsys(fn)
          # Given a custom field name like "RallyObjectID",
          # Return the systen name of 'custom_rallyobjectid'
          return 'custom_' + fn.to_s.downcase
        end

        def find_rally_test_case_by_oid(oid)
          if @@rally_cached_tc[oid].nil? || @@rally_cached_tc[oid].empty?
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

              str1 = ''
              if query_result.length > 1
                str1 = ' (using first found)'
              end
              RallyLogger.debug(self, "\tquery for '#{query.type}' returned '#{query_result.length}'#{str1}")
            rescue Exception => ex
              raise UnrecoverableException.copy(ex, self)
            end

            @@rally_cached_tc[oid] = query_result.first
            return query_result.first
          else
            return @@rally_cached_tc[oid]
          end

        end # of 'def find_rally_test_case_by_oid(oid)'
        
        def find_rally_test_set_by_name(name)
          begin
            query            = RallyAPI::RallyQuery.new()
            query.type       = 'testset'
            query.workspace  = @rally_connection.workspace
            query.fetch      = 'FormattedID,Name,Iteration,Project,ObjectID'
            query.limit      = 1
  
            base_string = "( Name contains \"#{name}\" )"
  
            query.query_string = base_string
            RallyLogger.debug(self, "Query Rally for '#{query.type}' using: #{query.query_string}")
            
            query_result = @rally_connection.rally.find(query)
            
            str1 = ''
            if query_result.length > 1
              str1 = ' (using first found)'
            end
            RallyLogger.debug(self, "\tquery for '#{query.type}' returned '#{query_result.length}'#{str1}")
          rescue Exception => ex
            raise UnrecoverableException.copy(ex, self)
          end
          
          return query_result.first
        end # of 'def find_rally_test_set_by_name(name)'
        
        def create_rally_test_set(name)
          RallyLogger.debug(self, "Creating a Rally TestSet named: '#{name}'")
          new_test_set = nil
          ts = { 'Name' => name }
          new_test_set = @rally_connection.rally.create('testset',ts)
          return new_test_set
        end
        
        def add_testcase_to_test_set(rally_test_case,rally_test_set)

          objectid = rally_test_set['ObjectID']
          if @@rally_cached_ts[objectid].nil?
            test_set = @rally_connection.rally.read('testset', objectid)  # not in cache... so read it from Rally
            if !test_set.nil? && !test_set.empty?
              @@rally_cached_ts[objectid] = test_set  # add it to cache for next time
            end
            str1 = 'Retrieved'  # logfile indication of cache hit rate
          else
            test_set = @@rally_cached_ts[rally_test_set['ObjectID']]
            str1 = 'Cached'  # logfile indication of cache hit rate
          end
          RallyLogger.info(self, "#{str1} Rally TestSet '#{test_set.FormattedID}/#{test_set.ObjectID}' currently has '#{test_set.TestCases.length}' TestCases")
          
          associated_test_cases = test_set['TestCases'] || []
          RallyLogger.debug(self, "Assure Rally TestCase '#{rally_test_case.FormattedID}/#{rally_test_case.ObjectID}' is in TestSet")
          found_tc = false
          associated_test_cases.each_with_index do |this_tc, ndx|
            if this_tc._ref == rally_test_case._ref
              RallyLogger.debug(self, "   TestCase is already in TestSet (@ #{ndx+1})")
              found_tc = true
              break  # quit searching - we found it so break out of loop
            end
          end

          if found_tc == false
            RallyLogger.debug(self, "   TestCase not in TestSet; will be added now")
            associated_test_cases = associated_test_cases.push(rally_test_case)

            refs = []
            associated_test_cases.each do |tc|
              refs.push({'_ref'=> tc['_ref']})
            end

            begin
              fields = { 'TestCases' => refs }
              updated_rally_test_set = rally_test_set.update(fields)
              @@rally_cached_ts[objectid] = updated_rally_test_set
            rescue Exception => ex
              RallyLogger.warning(self, "EXCEPTION occurred on Rally 'update' of TestSet '#{rally_test_set}'")
              RallyLogger.warning(self, "\tattempting to add '#{refs.length}' TestCases to TestSet")
              RallyLogger.warning(self, "\t   msg: '#{ex.message}'")
              raise RecoverableException.copy(ex, self)
            end
          end
        end # of 'def add_testcase_to_test_set(rally_test_case,rally_test_set)'
        
        def process_results(tr_testresults_list)
        
          RallyLogger.debug(self, "Running post process to associate test runs to test sets in Rally...")
         
          runs,run_ids = @other_connection.find_test_runs()
          RallyLogger.debug(self, "Found '#{run_ids.length}' run(s); ID's: '#{run_ids}'")
          
          runs.each_with_index do |run,run_ndx|
            RallyLogger.debug(self, "Begin processing 'run #{run_ndx+1}-of-#{runs.length}'; plan_id='#{run['plan_id']}'")
            #-----
            # For each run:
            #   1) Get TestRail TestPlan ID for this TestRun
            #   2) Find Rally story with that TestPlan ID value,
            #        if not found, skip and go to next run
            #   3) Find or create a Rally testset for this testrun
            #        add Rally story ID to the beginning of the name of the testset
            #   4) Get project & iteration from the rally story
            #   5) Add project & iteration to new testset
            #   6) Get TR testcases in this run (find-test-for-run)
            #        - for each TR testcase 
            #          - find equiv rally testcase (find-rally-testcase-by-oid)
            #          - add rally testcase to rally testset (from 3 above)
    
            #   1) Get TestRail TestPlan ID for this TestRun
            plan_id = run['plan_id']
            
            #   2) Find Rally story with that TestPlan ID value; if not found, skip and go to next run
            story = find_rally_story_with_plan_id(plan_id)
            if story.total_result_count < 1
              RallyLogger.warning(self, "Found no stories with a plan_id of '#{plan_id}'")
              next
            end
            
            #   3) Find or create a Rally testset for this testrun
            #        add Rally story ID to the beginning of the name of the testset
            rally_test_set = nil
            # Does a testset for this test run already exist in Rally?
            rally_test_set = find_rally_test_set_by_name("#{run['id']}:")
            if rally_test_set.nil?
              # If not, create one
              run_name = "#{story.first.FormattedID}: #{run['id']}: #{run['name']}"
              if !run['config'].nil?
                run_name = run_name + "#{run['config']}"
              end
              rally_test_set = create_rally_test_set(run_name)
              RallyLogger.debug(self, "TestSet created: '#{rally_test_set.FormattedID}'")
            else
              RallyLogger.debug(self, "TestSet found: '#{rally_test_set.FormattedID}'")
            end
            if rally_test_set.nil?
              RallyLogger.error(self, "Failed to find or create a testset in Rally; name='#{run_name}'")
              next # run, please
            end

            #   4) Get project & iteration from the rally story                       
            fields = {}
            project = story.first.Project
            iteration = story.first.Iteration
            
            #   5) Add project & iteration to new testset
            fields['Project'] = {'_ref'=> project['_ref']}
            if !iteration.nil?
              fields['Iteration'] =  {'_ref'=> iteration['_ref']}
            end
            rally_test_set.update(fields)
 
            
            #   6) Get TR testcases in this run (find-test-for-run)
            #        - for each TR testcase 
            #          - find equiv rally testcase (find-rally-testcase-by-oid)
            #          - add rally testcase to rally testset (from 3 above)
            testcases_for_run = @other_connection.find_tests_for_run(run['id'])
            RallyLogger.debug(self, "Found '#{testcases_for_run.length}' testcases for run_id '#{run['id']}'")
            rally_testcase_oids = []
            testcases_for_run.each do |testcase|
              if !testcase[cfsys(@other_connection.external_id_field)].nil?
                rally_testcase = find_rally_test_case_by_oid(testcase[cfsys(@other_connection.external_id_field)])
                if !rally_testcase.nil?
                  add_testcase_to_test_set(rally_testcase,rally_test_set)
                end
              else
                RallyLogger.warning(self, "TestRail testcase 'T#{testcase['id']}' not connected to a Rally testcase")
              end
            end
          end # of 'runs.each do |run|'

          RallyLogger.info(self,"Associate '#{tr_testresults_list.length}' TestResult(s) with the TestSet")
          tr_testresults_list.each do |testresult|
            RallyLogger.debug(self,"TestRail testresult: id='#{testresult['id']}'  test_id='#{testresult['status_id']}'  status_id='#{testresult['status_id']}'")
            RallyLogger.debug(self,"\t    _test: id='#{testresult['_test']['id']}'  case_id='#{testresult['_test']['case_id']}'  run_id='#{testresult['_test']['run_id']}'")
            RallyLogger.debug(self,"\t_testcase: id='#{testresult['_testcase']['id']}'  formattedid='#{testresult['_testcase'][cfsys(@other_connection.external_end_user_id_field)]}'")
            rally_test_set = find_rally_test_set_by_name("#{testresult['_test']['run_id']}:")
            if rally_test_set.nil?
              RallyLogger.debug(self,"test: <no test set found in Rally>")
            else
              RallyLogger.debug(self,"test: '#{testresult['_test']['run_id']}'")
            end
            rally_result = @rally_connection.find_result_with_build(testresult['id'])
            if !rally_result.nil? && !rally_test_set.nil?
              fields = { 'TestSet' => {'_ref'=>rally_test_set['_ref']} }
              begin
                rally_result.update(fields)
              rescue Exception => ex
                raise RecoverableException.new("Could not add #{rally_test_set.FormattedID} to #{rally_result._ref}\nMessage: #{ex.message}", self)
              end
            else
              RallyLogger.info(self, "No result found in Rally with Build: '#{testresult['id']}'")
            end
          end # of 'tr_testresults_list.each do |testresult|'
          
          RallyLogger.debug(self, "Completed running post process to associate test runs to test sets in Rally.")
        end # of 'def process_results(tr_testresults_list)'

        def find_rally_story_with_plan_id(plan_id)
          plan_id_field_on_stories = @other_connection.rally_story_field_for_plan_id
          if plan_id_field_on_stories.nil?
            RallyLogger.warning(self, "Config file contains no <RallyStoryFieldForPlanID> in the <TestRailConnection> section.")
          end
          RallyLogger.info(self, "Find Rally Story with '#{plan_id}' in '#{plan_id_field_on_stories}'")

          #Proposed:
          #ndx = plan_id.gsub(/^[Rr]/,'')
          #if !@@rally_cached_pid[ndx].nil?
          #    #use cache  
          #else
            @rally = @rally_connection.rally
            begin
              query            = RallyAPI::RallyQuery.new()
              query.type       = 'hierarchicalrequirement'
              query.workspace  = @rally_connection.workspace
              query.fetch      = "FormattedID,Name,Project,Iteration,#{plan_id_field_on_stories}"
  
              # try to find 123, or R123, or r123 ...
              base_query = "( ( (#{plan_id_field_on_stories} = \"#{plan_id}\") OR (#{plan_id_field_on_stories} = \"R#{plan_id}\") ) OR (#{plan_id_field_on_stories} = \"r#{plan_id}\") )"
                   
              query.query_string = base_query
              RallyLogger.debug(self, "Rally using query: '#{query.query_string}'")
              query_result = @rally.find(query)
            rescue Exception => ex
              raise UnrecoverableException.copy(ex, self)
            end
  
            count = query_result.total_result_count
            if count < 1
              #RallyLogger.warning(self, "  Found no Rally stories with a value in plan_id field")
            elsif count == 1
              fmtid = query_result.first.FormattedID
              RallyLogger.info(self, "  Found Rally story '#{fmtid}'")
            else # if there was more than one story found...
              fmtids = Array.new
              query_result.each do |us|
                fmtids.push(us.FormattedID)
              end
              RallyLogger.warning(self, "  Found these '#{count}' Rally stories with same plan_id value: '#{fmtids}'")
              # before just using the 'first', perhaps we should sort by FormattedID or ObjectID?
              fmtid = fmtids[0]
              RallyLogger.warning(self, "  (will use the first: '#{fmtid}')")
            end
          #end # of 'if !@@rally_cached_pid[ndx].nil?'

          return query_result
        end # of 'def find_rally_story_with_plan_id(plan_id)'
        
      end # of 'class CreateTestSets < PostServiceAction'
      
    end # of 'module PostServiceActions'
  end # of 'module WRK'
end # of 'module RallyEIF'
