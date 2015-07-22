# Copyright 2001-2014 Rally Software Development Corp. All Rights Reserved.

require 'rallyeif-wrk'
require './lib/testrail-api-master/ruby/testrail.rb'

RecoverableException   = RallyEIF::WRK::RecoverableException if not defined?(RecoverableException)
UnrecoverableException = RallyEIF::WRK::UnrecoverableException
RallyLogger            = RallyEIF::WRK::RallyLogger
XMLUtils               = RallyEIF::WRK::XMLUtils

module RallyEIF
  module WRK
    
    VALID_TESTRAIL_ARTIFACTS = ['testcase']
                          
    class TestRailConnection < Connection

      attr_reader   :testrail, :tr_project
      attr_accessor :project, :section_id
      attr_reader   :rally_story_field_for_plan_id
      
      #
      # Global info that will be obtained from the TestRail system.
      #
      @testrail           = '' # The connecton packet used to make request.
      @tr_project         = {} # Information about project in config file.
      @tr_cust_fields_tc  = {} # Hash of custom fields on test case.
      @tr_cust_fields_tcr = {} # Hash of custom fields on test case result.
      @tr_fields_tc       = {} # Hash of standard fields on test case.
      @tr_fields_tcr      = {} # Hash of standard fields on test case result.
      @tr_user_info       = {} # TestRail information about user in config file.
      
      def initialize(config=nil)
        super()
        read_config(config) if !config.nil?
      end
      
      def read_config(config)
        super(config)
        @url     = XMLUtils.get_element_value(config, self.conn_class_name.to_s, "Url")
        @project = XMLUtils.get_element_value(config, self.conn_class_name.to_s, "Project")
        # yes, it's weird to put a field name from a Rally artifact into the other connection
        # but this keeps us from overriding/monkey-patching the Rally connection class
        @rally_story_field_for_plan_id = XMLUtils.get_element_value(config, self.conn_class_name.to_s, "RallyStoryFieldForPlanID", false)
        @section_id = nil
      end
      
      def name()
        return "TestRail"
      end
      
      def version()
        return RallyEIF::TestRail::Version
      end

      def self.version_message()
        version_info = "#{RallyEIF::TestRail::Version}-#{RallyEIF::TestRail::Version.detail}"
        return "TestRailConnection version #{version_info}"
      end
      
      def get_backend_version()
        return "%s %s" % [name, version]
      end
#---------------------#
      def connect()    
        RallyLogger.debug(self, "********************************************************")
        RallyLogger.debug(self, "Connecting to TestRail:")
        RallyLogger.debug(self, "  Url               : #{@url}")
        RallyLogger.debug(self, "  Username          : #{@user}")
        RallyLogger.debug(self, "  Connector Name    : #{name}")
        RallyLogger.debug(self, "  Connector Version : #{version}")
        RallyLogger.debug(self, "  Artifact Type     : #{artifact_type}")
        RallyLogger.debug(self, "*******************************************************")   
        
        #
        # Set up a connection packet
        #
        @testrail          = ::TestRail::APIClient.new(@url)
        @testrail.user     = @user
        @testrail.password = @password
        

        #
        # PROJECTS:  Build a hash of TestRail projects
        #
        uri = 'get_projects'
        all_projects = @testrail.send_get(uri)
        
        if all_projects.length < 1
          raise UnrecoverableException.new("Could not find any projects in TestRail.\n TestRail api returned:#{ex.message}", self)
        end

        found_projects = []
        all_projects.each do |proj|
          if proj['name'] == @project
            found_projects.push proj
            if found_projects.length == 1
              RallyLogger.info(self,"Found project: P#{proj['id']}")
            end
            #RallyLogger.info(self,"\tid:#{proj['id']}  name:#{proj['name']}  url:#{proj['url']}   is_completed:#{proj['is_completed']}")
            RallyLogger.info(self,"         name: #{proj['name']} (id=#{proj['id']})")
            RallyLogger.info(self,"          url: #{proj['url']}")
            RallyLogger.info(self,"   suite_mode: #{proj['suite_mode']} (1: single suite, 2: 1+baselines, 3: multiple suites)")
            if proj['is_completed'] == true
              prettydate = Time.at(proj['completed_on']).to_datetime
              cdate = "(on #{prettydate})"
            else
              cdate = ''
            end
            RallyLogger.info(self," is_completed: #{proj['is_completed']} #{cdate}")
          end
        end
        if found_projects.length != 1
          raise UnrecoverableException.new("Found '#{found_projects.length}' projects named '#{@project}'; the connector needs one and only one", self)
        end
        @tr_project    = found_projects[0].to_hash
        @tr_project_sm = @tr_project['suite_mode']
        if @tr_project_sm == 3
          returned_suites = @testrail.send_get("get_suites/#{@tr_project['id']}")
          RallyLogger.info(self,"Found '#{returned_suites.length}' suites in above project:")
          @tr_suite_ids = Array.new
          returned_suites.each do |sweet|
            RallyLogger.info(self,"\tsuite id=#{sweet['id']}, name=#{sweet['name']}")
            @tr_suite_ids.push(sweet['id'])
          end
          #"description": "..",
          #"id": 1,
          #"name": "Setup & Installation",
          #"project_id": 1,
          #"url": "http://<server>/testrail/index.php?/suites/view/1"
        end
        @section_id    = get_default_section_id()['id']
          
          
        #
        # CUSTOM FIELDS:  Build a hash of custom fields for the given <Artifactype>.
        # Each entry:  {'system_name' => ['name', 'label', 'type_id', [ProjIDs]}
        #
        type_ids = ['?Unknown?-0',  # 0
                    'String',       # 1
                    'Integer',      # 2
                    'Text',         # 3
                    'URL',          # 4
                    'Checkbox',     # 5
                    'Dropdown',     # 6
                    'User',         # 7
                    'Date',         # 8
                    'Milestone',    # 9
                    'Steps',        # 10
                    '?Unknown?-11', # 11
                    'Multi-select', # 12
                   ]
        case @artifact_type.to_s
          
        when 'testcase'
          begin   
            cust_fields = @testrail.send_get('get_case_fields')
          rescue Exception => ex
            raise UnrecoverableException.new("Could not retrieve TestCase custom field names'.\n TestRail api returned:#{ex.message}", self)
          end
    
          @tr_cust_fields_tc  = {} # Hash of custom fields on test case.
          cust_fields.each do |item|
            # Ignore the custom field if it is not unassigned to any project...
            next if item['configs'] == []
              
            # Is this custom field global (for all projects)?
            if item['configs'][0].to_hash['context']['is_global'] == true
              # nil means good for all projects
              pids = nil
            else
              # not global, save the list of project IDs
              pids = item['configs'][0].to_hash['context']['project_ids']
            end
            @tr_cust_fields_tc[item['system_name']] =  [item['name'],  item['label'],  item['type_id'],  pids]
          end
          
        when 'testrun'
          # No way to get fields.
          
        when 'testplan'
          #
        when 'testresult'
          begin   
            cust_fields = @testrail.send_get('get_result_fields')
          rescue Exception => ex
            raise UnrecoverableException.new("Could not retrieve Test Result custom field names'.\n TestRail api returned:#{ex.message}", self)
          end
        
          @tr_cust_fields_tcr  = {} # Hash of custom fields on test case.
          cust_fields.each do |item|
            # Ignore the custom field if it is not unassigned to any project...
            next if item['configs'] == []
              
            # Is this custom field global (for all projects)?
            if item['configs'][0].to_hash['context']['is_global'] == true
              # nil means good for all projects
              pids = nil
            else
              # not global, save the list of project IDs
              pids = item['configs'][0].to_hash['context']['project_ids']
            end
            @tr_cust_fields_tcr[item['system_name']] = [item['name'],  item['label'],  item['type_id'], pids]
          end
          
        else
          RallyLogger.error(self, "Unrecognize value for <ArtifactType> '#{@artifact_type}'")
        end


        #
        # STANDARD FIELDS:  Build hash of TestCase standard fields
        #                   (done manually since there is no API method to get them).
        case @artifact_type.to_s

        when 'testcase'    # Field-name          Type (1=String, 2=Integer)
          @tr_fields_tc = { 'created_by'        => 2,
                            'created_on'        => 2,
                            'estimate'          => 1,
                            'estimate_forecast' => 1,
                            'id'                => 2,
                            'milestone_id'      => 2,
                            'priority_id'       => 2,
                            'refs'              => 1,
                            'section_id'        => 2,
                            'suite_id'          => 2,
                            'title'             => 1,
                            'type_id'           => 2,
                            'updated_by'        => 2,
                            'updated_on'        => 2}

        when 'testrun'
          # No way to get fields.
          
        when 'testresult' #  Field-name          Type (1=String, 2=Integer)
          @tr_fields_tcr = {'assignedto_id'     => 2,
                            'comment'           => 1,
                            'created_by'        => 2,
                            'created_on'        => 2,
                            'defects'           => 1,
                            'elapsed'           => 2,
                            'id'                => 2,
                            'status_id'         => 2,
                            'test_id '          => 2,
                            'version'           => 1}
                            
          when 'testplan'#  Field-name          Type (1=String, 2=Integer, 3=array, 4=bool)
          @tr_fields_tp =  {'assignedto_id'         => 2,
                            'blocked_count'         => 2,
                            'completed_on'          => 2,
                            'created_by'            => 2,
                            'created_on'            => 2,
                            'custom_status?_count'  => 2,
                            'description'           => 1,
                            'entries'               => 3,
                            'failed_count'          => 2,
                            'id'                    => 2,
                            'is_completed'          => 4,
                            'milestone_id'          => 2,
                            'name'                  => 1,
                            'passed_count'          => 2,
                            'project_id'            => 2,
                            'retest_count'          => 2,
                            'untested_count'        => 2,
                            'url'                   => 1}
            
        else
          RallyLogger.error(self, "Unrecognized value for <ArtifactType> '#{@artifact_type}' (msg1)")
        end


        #
        # USER INFO:  Request info for the user listed in config file
        #
        begin
          @tr_user_info = @testrail.send_get("get_user_by_email&email=#{@user}")
          RallyLogger.debug(self, "User information retrieve successfully for '#{@user}'")
        rescue Exception => ex
          raise UnrecoverableException.new("Cannot retrieve information for <User> '#{@user}'.\n TestRail api returned:#{ex.message}", self)
        end
        
        return @testrail
      end
      
      
      def add_run_to_plan(testrun,testplan)
        RallyLogger.debug(self, "Adding testrun '#{testrun}' to testplan '#{testplan}'")
        begin
          @testrail.send_post("add_plan_entry/#{testplan['id']}", 
          { 
            'suite_id'          => testrun['suite_id'],
            "runs" => [testrun]
          })
        rescue Exception => ex
          raise UnrecoverableException.new("Problem adding TestRun '#{testrun['id']}' to TestPlan '#{testplan['id']}'.\n TestRail api returned:#{ex.message}", self)
        end
        
      end
#---------------------#
      def create_internal(int_work_item)
        # Hardcode these until we understand more...
        run_id     = 1
        case_id    = 2
        RallyLogger.debug(self,"Preparing to create a TestRail: '#{@artifact_type}' in Section #{@section_id}")
        begin
          case @artifact_type.to_s.downcase
          when 'testcase'
            new_item = @testrail.send_post("add_case/#{@section_id}", int_work_item)
            gui_id = 'C' + new_item['id'].to_s # How it appears in the GUI
            RallyLogger.debug(self,"We just created TestRail '#{@artifact_type}' object #{gui_id}")
          when 'testrun'
            new_item = @testrail.send_post("add_run/#{@tr_project['id']}", int_work_item)
          when 'testplan'
            new_item = @testrail.send_post("add_plan/#{@tr_project['id']}", int_work_item)
          when 'testresult'
            run_id = int_work_item['run_id'] || run_id
            case_id = int_work_item['case_id'] || case_id
            new_item = @testrail.send_post("add_result_for_case/#{run_id}/#{case_id}", int_work_item)
            gui_id = '(no ID)'
          else
            raise UnrecoverableException.new("Unrecognized value for <ArtifactType> '#{@artifact_type}' (msg2)", self)
          end
        rescue RuntimeError => ex
          RallyLogger.debug(self,"Hep me Hep me 1!!!")
          raise RecoverableException.copy(ex, self)
        rescue Exception => ex
          RallyLogger.debug(self,"Hep me Hep me 2!!!")
          raise RecoverableException.copy(ex, self)
        end
        RallyLogger.debug(self,"Created #{@artifact_type} #{gui_id}")
        return new_item
      end
#---------------------#
      def delete(item)
        case @artifact_type.to_s.downcase
        when 'testcase'
          retval = @testrail.send_post("delete_case/#{item['id']}",nil)
        when 'testrun'
          retval = @testrail.send_post("delete_run/#{item['id']}",nil)
        when 'testplan'
          retval = @testrail.send_post("delete_plan/#{item['id']}",nil)
        when 'testresult'
          # ToDo: How to delete a Result?  Not in documentation?
        else
          raise UnrecoverableException.new("Unrecognize value for <ArtifactType> '#{@artifact_type}'", self)
        end
        return nil
      end
#---------------------#
      def disconnect()
        RallyLogger.info(self,"Would disconnect at this point if we needed to")
      end
#---------------------#
      def field_exists? (field_name)

        case @artifact_type.to_s
        when 'testcase'
          if (!@tr_cust_fields_tc.member? field_name.to_s.downcase) && (!@tr_fields_tc.member? field_name.to_s.downcase)
            if (!@tr_cust_fields_tc.member? 'custom_' + field_name.to_s.downcase)
              RallyLogger.error(self, "TestRail field '#{field_name.to_s}' not a valid field name for Test Cases in project '#{@project}'")
              RallyLogger.debug(self, "  available fields (standard): #{@tr_fields_tc}")
              RallyLogger.debug(self, "  available fields (custom): #{@tr_cust_fields_tc}")
              return false
            end
          end
          
        when 'testrun'
          raise UnrecoverableException.new('Unrecognize logic: field_exists? on "testrun"?', self)
          
        when 'testresult'
          
          special_fields = ['_testcase','_test']
          if (!@tr_cust_fields_tcr.member? field_name.to_s.downcase) && (!@tr_fields_tcr.member? field_name.to_s.downcase)
            if (!@tr_cust_fields_tcr.member? 'custom_' + field_name.to_s.downcase )  && ( !special_fields.member? field_name.to_s.downcase )
              RallyLogger.error(self, "TestRail field '#{field_name.to_s}' not a valid field name for Test Results in project '#{@project}'")
              RallyLogger.debug(self, "  available fields (standard): #{@tr_fields_tcr}")
              RallyLogger.debug(self, "  available fields (custom): #{@tr_cust_fields_tcr}")
              return false
            end
          end

        else
          raise UnrecoverableException.new("Unrecognize value for <ArtifactType> '#{@artifact_type}'", self)
        end
        
        return true
      end
#---------------------#
      def find(item, type=@artifact_type)
        case type.to_s.downcase
        when 'testcase'
          found_item = @testrail.send_get("get_case/#{item['id']}")
        
        when 'test'
          found_item = @testrail.send_get("get_test/#{item['id']}")
                    
        when 'testrun'
          raise UnrecoverableException.new('Unimplemented logic: find on "testrun"...', self)
        
        when 'testresult'
          raise UnrecoverableException.new('Unimplemented logic: find on "testresult"...', self)
        
        else
          raise UnrecoverableException.new("Unrecognize value for <ArtifactType> '#{type}'", self)
        end
        return found_item
      end
#---------------------#
      # find_by_external_id is forced from inheritance
      def find_by_external_id(external_id)
        case @artifact_type.to_s
        when 'testcase'
          begin

# ToDo: Add  milestone, section, etc

            artifact_array = @testrail.send_get("get_cases/#{@tr_project['id']}")
          rescue
            raise UnrecoverableException.new("Failed to find testcase objects with populated <ExternalID> field.\n TestRail api returned:#{ex.message}", self)
          end 
          
        when 'testrun'
          raise UnrecoverableException.new('Unimplemented logic: find_by_external_id on "testrun"...', self)

        when 'testresult'
          raise UnrecoverableException.new('Unimplemented logic: find_by_external_id on "testresult"...', self)

        else
          raise UnrecoverableException.new("Unrecognize value for <ArtifactType> '#{@artifact_type}'", self)
        end
        
        matching_artifacts = []
        ids = []
        artifact_array.each do |artifact|
          if artifact["custom_#{@external_id_field.downcase}"] == external_id
            matching_artifacts.push(artifact)
            ids.push get_id_value(artifact)
          end
        end

        if matching_artifacts.length < 1
          raise RecoverableException.new("No artifacts found with <ExternalID> = '#{external_id}'", self)
          return nil
        end
        
        if matching_artifacts.length > 1
          RallyLogger.warning(self, "More than one artifact found with <ExternalID> = '#{external_id}' (IDs=#{ids})")
          raise RecoverableException.new("More than one artifact found with <ExternalID> = '#{external_id}' (IDs=#{ids})", self)
          return nil
        end

        return matching_artifacts.first
      end
#---------------------#
      def find_new()
        RallyLogger.info(self, "Find new TestRail '#{@artifact_type}' objects")
        returned_artifacts = []
        case @artifact_type.to_s.downcase
        when 'testcase'
          begin
            returned_artifacts = @testrail.send_get("get_cases/#{@tr_project['id']}")
            matching_artifacts = filter_out_already_connected(returned_artifacts)
          rescue Exception => ex
            raise UnrecoverableException.new("Failed to find new testcases.\n TestRail api returned:#{ex.message}", self)
          end
        
        when 'testrun'
          raise UnrecoverableException.new('Unimplemented logic: find_new on "testrun"...', self)
        
        when 'testresult'
          matching_artifacts = find_test_results()
        else
          raise UnrecoverableException.new("Unrecognized value for <ArtifactType> '#{@artifact_type}' (msg3)", self)
        end

        RallyLogger.info(self, "Found '#{matching_artifacts.length}' new TestRail '#{@artifact_type}' objects")
        
        return matching_artifacts
      end
      
      def filter_out_already_connected(artifacts)
        #
        # Find only the new artifacts
        #
        matching_artifacts = []
        artifacts.each do |artifact|
          if artifact["custom_#{@external_id_field.downcase}"].nil?
            matching_artifacts.push(artifact)
          end
        end
        return matching_artifacts
      end
      
      def find_test_runs()
        plans = find_test_plans()
        runs = []
        plans.each do |plan|
          runs = runs.concat(plan['runs'])
        end
        
        begin
          orphan_runs = @testrail.send_get("get_runs/#{@tr_project['id']}")
          runs = orphan_runs.concat(runs)
        rescue Exception => ex
          raise UnrecoverableException.new("Failed to find any Test Runs.\n TestRail api returned:#{ex.message}", self)
        end
  
        return runs
      end
      
      def find_test_for_run(run_id)
        tests = []
          
        begin
          tests = @testrail.send_get("get_tests/#{run_id}")
        rescue Exception => ex
          raise UnrecoverableException.new("Failed to find any Tests.\n TestRail api returned:#{ex.message}", self)
        end
        return tests
      end

      # find and populated related data for plans
      def find_test_plans()
        begin
          plan_shells = @testrail.send_get("get_plans/#{@tr_project['id']}")
          plans = []
          plan_shells.each do |plan_shell|
            plan = @testrail.send_get("get_plan/#{plan_shell['id']}")
            runs = []
            tests = []
              
            entries = plan['entries'] || []
            entries.each do |entry|
              run_shells = entry['runs']
              run_shells.each do |run_shell|
                run = @testrail.send_get("get_run/#{run_shell['id']}")
                runs.push(run)
                test = @testrail.send_get("get_tests/#{run_shell['id']}")
                tests.push(test)
              end
            end
            plan['runs'] = runs
            plan['tests'] = tests
            plans.push(plan)
          end
        rescue Exception => ex
          raise UnrecoverableException.new("Failed to find any Test Plans.\n TestRail api returned:#{ex.message}", self)
        end
      
        return plans
      end

      def find_test_results()
        # have to iterate over the runs
        runs = find_test_runs()
        test_results = []
        runs.each do |run|
          begin
            run_id = run['id']
            results = @testrail.send_get("get_results_for_run/#{run_id}")
            filtered_results = filter_out_already_connected(results)
            test_results = test_results.concat(filtered_results)
            # matching candidates are filtered below...
          rescue Exception => ex
            raise UnrecoverableException.new("Failed to find new Test Results.\n TestRail api returned:#{ex.message}", self)
          end
        end
        
        # pack test result with referenced test and test case
        RallyLogger.debug(self,"Unfiltered test case result set count:  #{test_results.length}")
        RallyLogger.debug(self,"Filtering out test case results that have an unconnected test case")
        
        filtered_test_results = []
        test_results.each do |test_result|
          test = find({ 'id' => test_result['test_id'] }, 'test')
          test_result['_test'] = test
          test_case = find({ 'id' => test['case_id'] }, 'testcase')
          test_result['_testcase'] = test_case
          # we only care about results where the test_case is also connected to Rally
          if !test_case["custom_#{@external_id_field.downcase}"].nil?
            filtered_test_results.push(test_result)
          end
        end
        
        return filtered_test_results
      end
     
#---------------------#
      def find_updates(reference_time)
        RallyLogger.info(self, "Find updated TestRail '#{@artifact_type}' objects since '#{reference_time}'")
        unix_time = reference_time.to_i
        artifact_array = []
        case @artifact_type.to_s
        when 'testcase'
          begin
            result_array = @testrail.send_get("get_cases/#{@tr_project['id']}&updated_after=#{unix_time}")
            # throw away those without extid
            artifact_array = []
            result_array.each do |item|
              if item["custom_#{@external_id_field.downcase}"] != nil
                artifact_array.push(item)
              end
            end
          rescue Exception => ex
            raise UnrecoverableException.new("Failed to find new testcases.\n TestRail api returned:#{ex.message}", self)
          end
        
        when 'testrun'
          raise UnrecoverableException.new('Not available for "testrun": find_updates..', self)
            
        when 'testresult'
          raise UnrecoverableException.new('Not available for "testresult": find_updates...', self)

        else
          raise UnrecoverableException.new("Unrecognize value for <ArtifactType> '#{@artifact_type}'", self)
        end
        RallyLogger.info(self, "Found '#{artifact_array.length}' updated '#{@artifact_type}' objects in '#{name()}'")

        return artifact_array
      end
#---------------------#
#      def get_default_section_id()
#RallyLogger.debug(self,"JPKdebug: #{@tr_project['id']}")
#RallyLogger.debug(self,"JPKdebug: get_sections/#{@tr_project['id']}")
#        begin
#          returned_artifacts = @testrail.send_get("get_sections/#{@tr_project['id']}")
#        rescue Exception => ex
#          RallyLogger.warning(self, "Cannot find sections: #{ex.message}")
#        end
#        
#        if returned_artifacts.nil?
#          return {'id' => -1}
#        else
#          RallyLogger.debug(self, "Found '#{returned_artifacts.length}' sections:")
#          returned_artifacts.each do |sec|
#            RallyLogger.debug(self, "\tid=#{sec['id']},  suite_id=#{sec['suite_id']},  name=#{sec['name']}")
#          end
#RallyLogger.debug(self,"JPKdebug: returned_artifacts.class=#{returned_artifacts.class}")
##RallyLogger.debug(self,"JPKdebug: returned_artifacts.length=#{returned_artifacts.length}")
#          return returned_artifacts.first || {'id' => -1}
#        end
#      end
#---------------------#      
      def get_default_section_id()
        begin
          returned_artifacts = @testrail.send_get("get_sections/#{@tr_project['id']}")
        rescue Exception => ex
          RallyLogger.warning(self, "Cannot find sections: #{ex.message}")
        end
     
        RallyLogger.debug(self, "Found '#{returned_artifacts.length}' sections:")
        returned_artifacts.each do |sect|
          RallyLogger.debug(self, "    #{sect.select{|x| x!="description"}}") # description is too ugly for log file
        end
        return returned_artifacts.first || {'id' => -1}
      end      
#---------------------#
      # This method will hide the actual call of how to get the id field's value
      def get_id_value(artifact)
        return get_value(artifact,'id')
      end
#---------------------#
      def get_object_link(artifact)
        # We want:  "<a href='https://<TestRail server>/<Artifact ID>'>link</a>"
        linktext = artifact[@id_field] || 'link'
        it = "<a href='https://#{@url}/#{artifact['id']}'>#{linktext}</a>"
        return it
      end
#---------------------#
      def get_suite_ids(connection,projid)
        all_suites = @testrail.send_get("get_suites/#{projid}")
        return all_suites
      end
#---------------------#
      def get_value(artifact,field_name)
        return artifact["#{field_name.downcase}"]
      end
#---------------------#
      def pre_create(int_work_item)
        return int_work_item
      end
#---------------------#
      def update_external_id_fields(artifact, external_id, end_user_id, item_link)
        if @artifact_type.to_s.downcase == "testresult"
          return artifact
        end
        
        new_fields = {}
        if !external_id.nil?
          sys_name = 'custom_' + @external_id_field.to_s.downcase
          new_fields[sys_name] = external_id
          RallyLogger.debug(self, "Updating TestRail item <ExternalIDField>: '#{sys_name}' to '#{external_id}'")
        end

        # Rally gives us a full '<a href=' tag
        if !item_link.nil?
          url_only = item_link.gsub(/.* href=["'](.*?)['"].*$/, '\1')
          if !@external_item_link_field.nil?
            sys_name = 'custom_' + @external_item_link_field.to_s.downcase
            new_fields[sys_name] = url_only
            RallyLogger.debug(self, "Updating TestRail item <CrosslinkUrlField>: '#{sys_name}' to '#{url_only}'")
          end
        end

        if !@external_end_user_id_field.nil?
          sys_name = 'custom_' + @external_end_user_id_field.to_s.downcase
          new_fields[sys_name] = end_user_id
          RallyLogger.debug(self, "Updating TestRail item <ExternalEndUserIDField>: '#{sys_name}' to '#{end_user_id}'")
        end
        
        updated_item = update_internal(artifact, new_fields)
        return updated_item
      end
#---------------------#
      def update_internal(artifact, new_fields)
        #artifact.update_attributes int_work_item
        case @artifact_type.to_s.downcase
        when 'testcase'
          all_fields = artifact
          all_fields.merge!(new_fields)
          updated_item = @testrail.send_post("update_case/#{artifact['id']}", all_fields)

        when 'testrun'
          all_fields = artifact
          all_fields.merge!(new_fields)
          updated_item = @testrail.send_post("update_run/#{artifact['id']}", all_fields)

        when 'testresult'
          raise UnrecoverableException.new('Unimplemented logic: update_internal on "testresult"...', self)

        else
          raise UnrecoverableException.new("Unrecognize value for <ArtifactType> '#{@artifact_type}'", self)
        end
        return updated_item
      end
#---------------------#
      def validate
        status_of_all_fields = true  # Assume all fields passed
        
        #sys_name = 'custom_' + @external_id_field.to_s.downcase
        if !field_exists?(@external_id_field)
          status_of_all_fields = false
          RallyLogger.error(self, "TestRail <ExternalIDField> '#{@external_id_field}' does not exist")
        end

        if @id_field
          if !field_exists?(@id_field)
            status_of_all_fields = false
            RallyLogger.error(self, "TestRail <IDField> '#{@id_field}' does not exist")
          end
        end

        if @external_end_user_id_field
          if !field_exists?(@external_end_user_id_field)
            status_of_all_fields = false
            RallyLogger.error(self, "TestRail <ExternalEndUserIDField> '#{@external_end_user_id_field}' does not exist")
          end
        end
        
        return status_of_all_fields
      end
#---------------------#
    end
  end
end
