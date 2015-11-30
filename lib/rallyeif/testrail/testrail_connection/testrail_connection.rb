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

      attr_reader   :testrail,  :tr_project
      attr_reader   :all_suites,  :all_sections
      attr_reader   :rally_story_field_for_plan_id
      attr_reader   :run_days_to_search, :run_days_as_unixtime
      attr_accessor :project,  :section_id
      attr_accessor :time_of_last_api_call
      
      #
      # Global info that will be obtained from the TestRail system.
      #
      @testrail           = '' # The connecton packet used to make request.
      @tr_project         = {} # Information about project in config file.
      @all_suites         = {} # All suites in the project.
      @all_plans          = {} # All plans in the project (to be added... limit by PlanID's)
      @all_sections       = {} # All sections in the project
      @tr_cust_fields_tc  = {} # Hash of custom fields on test case.
      @tr_cust_fields_tcr = {} # Hash of custom fields on test case result.
      @tr_fields_tc       = {} # Hash of standard fields on test case.
      @tr_fields_tcr      = {} # Hash of standard fields on test case result.
      @tr_user_info       = {} # TestRail information about user in config file.
        
      @tr_api_time_of_first_call    = -1.0  # for measuring fequency of TestRail API calls
      @tr_api_time_of_previous_call = -1.0  #
      @tr_api_time_max_elapsed      = +9.0  # max time that occurred between API calls
      @tr_api_time_min_elapsed      = -1.0  #
      
      @tr_api_retry_maximum         = 3   # How many retries to do for failed API calls
      @tr_api_retry_current         = 0   #
      @tr_api_total_retries         = 0   # Keep a total for the run  
      @tr_api_max_try_count         = 0   # Highest number of tries on a call

      attr_accessor :tr_api_time_of_first_call
      attr_accessor :tr_api_time_of_previous_call
      attr_accessor :tr_api_time_max_elapsed
      attr_accessor :tr_api_time_min_elapsed
      
      attr_accessor :tr_api_retry_maximum
      attr_accessor :tr_api_retry_current
      attr_accessor :tr_api_total_retries  
      attr_accessor :tr_api_max_try_count
      
      def initialize(config=nil)
        super()
        read_config(config) if !config.nil?
      end
      
      def read_config(config)
        super(config)
        @url       = XMLUtils.get_element_value(config, self.conn_class_name.to_s, "Url")
        @project   = XMLUtils.get_element_value(config, self.conn_class_name.to_s, "Project")

        # yes, it's weird to put a field name from a Rally artifact into the other connection
        # but this keeps us from overriding/monkey-patching the Rally connection class
        @rally_story_field_for_plan_id = XMLUtils.get_element_value(config, self.conn_class_name.to_s, "RallyStoryFieldForPlanID", false)

        @section_id         = nil
        @cfg_suite_ids      = XMLUtils.get_element_value(config, self.conn_class_name.to_s, "SuiteIDs", false)
        @cfg_plan_ids       = XMLUtils.get_element_value(config, self.conn_class_name.to_s, "PlanIDs", false) # (to be added... limit by PlanID's)

        # Determine how far back in time to look for updates on TR TestCases
        @run_days_to_search = XMLUtils.get_element_value(config, self.conn_class_name.to_s, "RunDaysToSearch", false).to_f
        if @run_days_to_search.nil?
          @run_days_to_search = 14.0 # Default for how far back to search for NEW TestCases and TestResults
        end
        seconds_in_a_day = 60.0*60.0*24.0
        @run_days_as_unixtime = (Time.now.to_f - seconds_in_a_day*@run_days_to_search).to_i
   
        # TR_SysCell - allow user some hidden overrides via environment variables.
        # Please document here. Presents of following strings engage the option.
        #   CasesCreated  - Use created_after on search for cases instead of updated_after in find_new_testcases()
        #   ShowTRvars    - Show TestResult vars in find_test_results() on special condition 
        @tr_sc = Array.new
        values = ENV['TR_SysCell']
        if !values.nil?
          @tr_sc = values.split(',')
        end
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
        RallyLogger.debug(self, "  Run days to search: #{@run_days_to_search} (back to #{Time.at(@run_days_as_unixtime)})")
        if !@tr_sc.empty?
          RallyLogger.debug(self, "  ENV TR_SysCell    : #{@tr_sc}")
        end
        RallyLogger.debug(self, "********************************************************")
        
        @tr_api_time_of_first_call    = -1.0 # for measuring fequency of TestRail API calls
        @tr_api_time_of_previous_call = -1.0
        @tr_api_retry_maximum         = 3
        @tr_api_retry_current         = 0
        @tr_api_max_try_count         = 0
        
        #
        # Set up a connection packet
        #
        begin
          @testrail          = ::TestRail::APIClient.new(@url)
          @testrail.user     = @user
          @testrail.password = @password
        rescue
          raise UnrecoverableException.new("Failed to create TestRail structure.", self)
        end

        #
        # PROJECTS:  Build a hash of TestRail projects
        #            (not necessary to have them all, but we have to find ours anyway)
        #
        uri = 'get_projects'
        all_projects = testrail_send('get', uri)
        if all_projects.length < 1
          raise UnrecoverableException.new("Could not find any projects in TestRail.", self)
        end

        # We should find one and only project name matching the one we are looking for. 
        found_projects = []
        all_projects.each do |proj|
          if proj['name'] == @project
            found_projects.push proj
            cdate = ''
            if proj['is_completed'] == true
              cdate = "(on #{Time.at(proj['completed_on']).to_datetime})" # pretty date
            end
            RallyLogger.info(self,"Found project: P#{proj['id']}")
            RallyLogger.info(self,"         name: #{proj['name']} (id=#{proj['id']})")
            RallyLogger.info(self,"          url: #{proj['url']}")
            RallyLogger.info(self,"   suite_mode: #{proj['suite_mode']} (1: single suite, 2: 1+baselines, 3: multiple suites)")
            RallyLogger.info(self," is_completed: #{proj['is_completed']} #{cdate}")
          end
        end
        if found_projects.length != 1
          raise UnrecoverableException.new("Found '#{found_projects.length}' projects named '#{@project}'; the connector needs one and only one", self)
        end
        @tr_project = found_projects[0].to_hash
        
        # Build suite info...
        @tr_project_sm = @tr_project['suite_mode']
        @tr_suite_ids = Array.new
        @all_suites = get_all_suites()
        RallyLogger.info(self,"Found '#{@all_suites.length}' suites in above project:")
        @all_suites.each do |next_suite|
          RallyLogger.info(self,"\tSuite S#{next_suite['id']}: name=#{next_suite['name']}")
          @tr_suite_ids.push(next_suite['id'])
        end
        # Handle config file: <SuiteIDs>1,2,3,4</SuiteIDs>
        if !@cfg_suite_ids.nil?
          suite_ids = @cfg_suite_ids.split(',')     # Make array from one string
          suite_ids.map!{ |s| s.gsub(/^[sS]/, '') } # Remove potential leading 'S' (i.e. ["S1", "S2", "S3", ...])
          suite_ids.map!{|s|s.to_i}                 # Convert array of strings to integers
          unknown_ids = suite_ids - @tr_suite_ids   # Did they specify any we did not find?
          if !unknown_ids.empty?
            raise UnrecoverableException.new("Found unknown ID(s) in config file <SuiteIDs> tag: '#{unknown_ids}'", self)
          end
          
          new_list = Array.new        # Make a new list of suites
          @all_suite_ids = Array.new  # Keep a list of suite IDs
          @all_suites.each do |next_suite|
            if suite_ids.include?(next_suite['id'])
              new_list.push(next_suite)
              @all_suite_ids.push(next_suite['id'])
            end
          end
          @all_suites = new_list
          mesg = 'be limited to suites specified' # For logger msg below
        else
          @all_suite_ids = @tr_suite_ids
          mesg = 'include all suites found'
        end
        RallyLogger.debug(self, "Future searches will #{mesg}: '#{@all_suite_ids}'")

        # Handle config file: <PlanIDs>1,2,3,4</PlanIDs>
        # (to be added... limit by PlanID's)
        #
        # ...code here...
        #   I beleive the code would be something like:
        #       - GET index.php?/api/v2/get_plans/:project_id
        #       - then iterate thru all the plans:
        #           - then iterate thru all the entries in a plan: (maybe be only one?)
        #               - then iterate thru all the runs in an entry:
        #                   - if the suite_id of this run is in the list '@all_suite_ids', then keep it
        #                     otherwise throw it away
        #       - exit with an updated list of suites

        # Build section info...
        @tr_section_ids = Array.new
        @all_sections = get_all_sections()
        RallyLogger.debug(self, "Found '#{@all_sections.length}' sections")
        @all_sections.each do |next_section|
          RallyLogger.debug(self, "\tid='#{next_section['id']}', suite_id='#{next_section['suite_id']}' name='#{next_section['name']}'")
          @tr_section_ids.push(next_section['id'])
        end
    
        # Get custom-field names where possible...
        case @artifact_type.to_s
        when 'testcase'
          uri = 'get_case_fields'
          begin
            uri = 'get_case_fields'
            cust_fields = testrail_send('get', uri)
          rescue Exception => ex
            RallyLogger.warning(self, "EXCEPTION occurred on TestRail API 'send_get(#{uri})':")
            RallyLogger.warning(self, "\tMessage: #{ex.message}")
            raise UnrecoverableException.new("\tFailed to retrieve TestRails TestCase custom-field names", self)
          end
    
          @tr_cust_fields_tc  = {} # Hash of custom fields on test case.
          cust_fields.each do |item|
            # Ignore the custom field if it is not assigned to any project...
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
          
        when 'testrun'      # No custom-fields on this object.
        when 'testplan'     # No custom-fields on this object.
        when 'testsuite'    # No custom-fields on this object.
        when 'testsection'  # No custom-fields on this object.

        when 'testresult'
          begin
            uri = 'get_result_fields'
            cust_fields = testrail_send('get', uri)
          rescue Exception => ex
            RallyLogger.warning(self, "EXCEPTION occurred on TestRail API 'send_get(#{uri})':")
            RallyLogger.warning(self, "\tMessage: #{ex.message}")
            raise UnrecoverableException.new("\tFailed to retrieve TestRails TestResult custom-field names", self)
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
          RallyLogger.error(self, "Unrecognize value for <ArtifactType> '#{@artifact_type.to_s}' (msg1)")
        end # of 'case @artifact_type.to_s'


        #
        # STANDARD FIELDS:  Build hash of Test Case standard fields
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
        when 'testplan'
        when 'testrun'
        when 'testsuite'
        when 'testsection'
        
        else
          RallyLogger.error(self, "Unrecognized value for <ArtifactType> '#{@artifact_type}' (msg2)")
        end


        #
        # USER INFO:  Request info for the user listed in config file
        #
        uri = "get_user_by_email&email=#{@user}"
        begin
          uri = "get_user_by_email&email=#{@user}"
          @tr_user_info = testrail_send('get', uri)
          RallyLogger.debug(self, "User information retrieve successfully for '#{@user}'")
        rescue Exception => ex
          RallyLogger.warning(self, "EXCEPTION occurred on TestRail API 'send_get(#{uri})':")
          RallyLogger.warning(self, "\tMessage: #{ex.message}")
          raise UnrecoverableException.new("\tFailed to retrieve information for <User> '#{@user}'", self)
        end
        
        RallyLogger.debug(self, "User information retrieved successfully for '#{@user}'")

        return @testrail

      end # 'def connect()'
#---------------------#      
      def add_run_to_plan(testrun,testplan)
        RallyLogger.debug(self, "Preparing to add testrun: '#{testrun}'")
        RallyLogger.debug(self, "             to testplan: '#{testplan}'")

        uri = "add_plan_entry/#{testplan['id']}"
        extra_fields = { 'suite_id' => testrun['suite_id'], 'runs' => [testrun] }
        begin
          uri = "add_plan_entry/#{testplan['id']}"
          extra_fields = { 'suite_id' => testrun['suite_id'], 'runs' => [testrun] }
          new_plan_entry = testrail_send('post', uri, extra_fields)
          RallyLogger.debug(self, "New plan entry: '#{new_plan_entry}'")
        rescue Exception => ex
          RallyLogger.warning(self, "EXCEPTION occurred on TestRail API during 'send_post(arg1,arg2)'")
          RallyLogger.warning(self, "\targ1: '#{uri}'")
          RallyLogger.warning(self, "\targ2: '#{extra_fields}'")
          RallyLogger.warning(self, "\tmsg : '#{ex.message}'")
          raise UnrecoverableException.new("\tFailed to add TestRun id='#{testrun['id']}' to TestPlan id='#{testplan['id']}'", self)
        end
        
        RallyLogger.debug(self, "New plan entry: '#{new_plan_entry}'")

        return new_plan_entry
      end
#---------------------#
      # Get custom field system name
      def cfsys(fn)
        # Given a custom field name like "RallyObjectID",
        # Return the systen name of 'custom_rallyobjectid'
        return 'custom_' + fn.to_s.downcase
      end
#---------------------#
      def create_internal(int_work_item)
#        if @all_sections.empty?
#          section_id = 1
#        else
#          section_id = @all_sections[0]['id'] # put in first section
#        end
#        if @all_suites.empty?
#          suite_id = 0
#        else
#          suite_id = @all_suites[0]['id'] # put in first suite
#        end
        
        begin
          case @artifact_type.to_s.downcase

          when 'testcase'
            section_id = int_work_item['section_id']
            RallyLogger.debug(self,"Preparing to create a TestRail '#{@artifact_type.to_s.downcase}' in Section '#{section_id}'")
            uri = "add_case/#{section_id}"
            new_item = testrail_send('post', uri, int_work_item)
            gui_id = 'C' + new_item['id'].to_s # How it appears in the GUI
            extra_info = ''
            #RallyLogger.debug(self,"We just created TestRail '#{@artifact_type}' object #{gui_id}")
            
          when 'testrun'
            suite_id = int_work_item['suite_id']
            RallyLogger.debug(self,"Preparing to create a TestRail '#{@artifact_type.to_s.downcase}' in Suite 'S#{suite_id}'")
            uri = "add_run/#{@tr_project['id']}&suite_id=#{suite_id}"
            new_item = testrail_send('post', uri, int_work_item)
            gui_id = 'R' + new_item['id'].to_s # How it appears in the GUI
            extra_info = ''
            
          when 'testplan'
            RallyLogger.debug(self,"Preparing to create a TestRail '#{@artifact_type.to_s.downcase}'")
            uri = "add_plan/#{@tr_project['id']}"
            new_item = testrail_send('post', uri, int_work_item)
            gui_id = 'R' + new_item['id'].to_s # How it appears in the GUI
            
            # Build a string of info about entries created (for log file)
            str1 = ''
            new_item['entries'].each_with_index do |e,ndx|
              if ndx == 0
                str1 = new_item['entries'].length.to_s + ' entries:('
              else
                str1 = str1 + ','
              end  
              str1 = str1 + e['id'].to_s
              str1 = str1 + ')' if ndx == new_item['entries'].length-1
            end

            # Build a string info about runs created (for log file)
            str2 = ''
            new_item['entries'].each_with_index do |e,ndx|
              e['runs'].each_with_index do |r,ndx|
                if ndx == 0
                  str2 = str2 + ' runs:('
                else
                  str2 = str2 + ','
                end  
                str2 = str2 + r['id'].to_s
                str2 = str2 + ')' if ndx == e['runs'].length-1
              end
            end
            extra_info = "; #{str1}; #{str2}"

          when 'testsuite'
            RallyLogger.debug(self,"Preparing to create a TestRail 'testsuite'")
            uri = "add_suite/#{@tr_project['id']}"
            new_item = testrail_send('post', uri, int_work_item)
                  # Returns:
                  #       {"id"=>97,
                  #        "name"=>"Suite '1' of '5'",
                  #        "description"=>"One of JPKole's test suites.",
                  #        "project_id"=>55,
                  #        "is_master"=>false,
                  #        "is_baseline"=>false,
                  #        "is_completed"=>false,
                  #        "completed_on"=>nil,
                  #        "url"=>"https://tsrally.testrail.com/index.php?/suites/view/97"}
            gui_id = 'S' + new_item['id'].to_s # How it appears in the GUI
            extra_info = ''

          when 'testsection'
            RallyLogger.debug(self,"Preparing to create a TestRail 'testsection'")
            uri = "add_section/#{@tr_project['id']}"
            new_item = testrail_send('post', uri, int_work_item)
                  # Returns:
            gui_id = new_item['id'].to_s # How it appears in the GUI
            extra_info = ''
            
          when 'testresult'
            run_id = int_work_item['run_id'] || run_id
            case_id = int_work_item['case_id'] || case_id
            RallyLogger.debug(self,"Preparing to create a TestRail '#{@artifact_type.to_s.downcase}' for run_id='R#{run_id}', case_id='T#{case_id}'")
            uri = "add_result_for_case/#{run_id}/#{case_id}"
            new_item = testrail_send('post', uri, int_work_item)
            gui_id = "(id='#{new_item['id']}' test_id='#{new_item['test_id']}')"
            extra_info = ''
            
          else
            raise UnrecoverableException.new("Unrecognized value for <ArtifactType> '#{@artifact_type.to_s.downcase}' (msg2)", self)
          end
        rescue RuntimeError => ex1
          RallyLogger.debug(self,"Runtime error has occurred")
          raise RecoverableException.copy(ex1, self)
        rescue Exception => ex2
          RallyLogger.warning(self, "EXCEPTION occurred on TestRail API during 'send_post'")
          RallyLogger.warning(self, "\targ1: '#{uri}'")
          RallyLogger.warning(self, "\targ2: '#{int_work_item})'")
          RallyLogger.warning(self, "\tmsg : '#{ex2.message}'")
          raise RecoverableException.copy(ex2, self)
        end
        RallyLogger.debug(self,"Created TestRail '#{@artifact_type}' number '#{gui_id}'#{extra_info}")
        return new_item
      end
#---------------------#
      def delete(item)
        begin
          case @artifact_type.to_s.downcase
          when 'testcase'
            uri = "delete_case/#{item['id']}"
            retval = testrail_send('post', uri,nil)
          when 'testrun'
            uri = "delete_run/#{item['id']}"
            retval = testrail_send('post', uri,nil)
          when 'testplan'
            uri = "delete_plan/#{item['id']}"
            retval = testrail_send('post', uri,nil)
          when 'testsuite'
            uri = "delete_suite/#{item['id']}"
            retval = testrail_send('post', uri,nil)
          when 'testsection'
            # Don't try to delete it unless it exist.
            get_all_sections().each do |next_section|
              uri = nil
              if next_section['id'] == item['id']
                uri = "delete_section/#{item['id']}"
                retval = testrail_send('post', uri,nil)
                break
              end
            end
            if uri.nil?
              RallyLogger.debug(self,"NOTE: TestRail section '#{item['id']}' appears to be already deleted; ignored")
            end
          when 'testresult'
            # ToDo: How to delete a Result?  Not in documentation?
            uri = 'n/a'
            RallyLogger.debug(self,"NOTE: TestRail has no API for deleting a 'testresult'; ignored")
          else
            raise UnrecoverableException.new("Unrecognize value for <ArtifactType> '#{@artifact_type.to_s.downcase}' (msg2)", self)
          end
        rescue Exception => ex
          RallyLogger.warning(self, "EXCEPTION occurred on TestRail API 'send_post(#{uri}, nil)':\n")
          RallyLogger.warning(self, "\tMessage: #{ex.message}")
          raise RecoverableException.new("\tFailed to delete '#{@artifact_type.to_s.downcase}'; id='#{item['id']}'", self)
        end
        return nil
      end
#---------------------#
      def disconnect()
        RallyLogger.info(self,"Would disconnect at this point if we needed to")
        RallyLogger.debug(self,"@tr_api_max_try_count='#{@tr_api_max_try_count}'")
      end
#---------------------#
      def field_exists? (field_name)

        case @artifact_type.to_s
        when 'testcase'
          if (!@tr_cust_fields_tc.member? field_name.to_s.downcase) && (!@tr_fields_tc.member? field_name.to_s.downcase)
            if (!@tr_cust_fields_tc.member? cfsys(field_name))
              RallyLogger.error(self, "TestRail field '#{field_name.to_s}' not a valid field name for TestCases in project '#{@project}'")
              RallyLogger.debug(self, "  available fields (standard): #{@tr_fields_tc}")
              RallyLogger.debug(self, "  available fields (custom): #{@tr_cust_fields_tc}")
              return false
            end
          end
          
        when 'testresult'
          special_fields = ['_testcase','_test']
          if (!@tr_cust_fields_tcr.member? field_name.to_s.downcase) && (!@tr_fields_tcr.member? field_name.to_s.downcase)
            if (!@tr_cust_fields_tcr.member? cfsys(field_name) )  && ( !special_fields.member? field_name.to_s.downcase )
              RallyLogger.error(self, "TestRail field '#{field_name.to_s}' not a valid field name for TestResults in project '#{@project}'")
              RallyLogger.debug(self, "  available fields (standard): #{@tr_fields_tcr}")
              RallyLogger.debug(self, "  available fields (custom): #{@tr_cust_fields_tcr}")
              return false
            end
          end

        else
          raise UnrecoverableException.new("Unrecognize value for <ArtifactType> '#{@artifact_type.to_s}' (msg3)", self)
        end
        
        return true
      end
#---------------------#
      def filter_out_already_connected(artifacts)
        #
        # Find only the new artifacts (i.e. reject those with a populated external_id field)
        #
        matching_artifacts = []
        rejected_artifacts = []
        artifacts.each do |artifact|
          if artifact[cfsys(@external_id_field)].nil?
            matching_artifacts.push(artifact)
          else
            rejected_artifacts.push(artifact)
          end
        end
        return matching_artifacts,rejected_artifacts
      end
#---------------------#
      def find(item, type=@artifact_type)
        if !(/\A\d+\z/ === item['id'].to_s)
          raise RecoverableException.new("\tError in find(item,#{type});  non-integer item['id']='#{item['id']}')", self)
        end
        begin
          case type.to_s.downcase

          when 'testcase'
            uri = "get_case/#{item['id']}"
            found_item = testrail_send('get', uri)
          
          when 'test'
            uri = "get_test/#{item['id']}"
            found_item = testrail_send('get', uri)
                      
          when 'testrun'
            raise UnrecoverableException.new('Unimplemented logic: find on "testrun"...', self)
          
          when 'testresult'
            raise UnrecoverableException.new('Unimplemented logic: find on "testresult"...', self)
          
          else
            raise UnrecoverableException.new("Unrecognize value for <ArtifactType> '#{type}' (msg4)", self)
          end
        rescue Exception => ex
          RallyLogger.warning(self, "EXCEPTION occurred on TestRail API 'send_get(#{uri})':\n")
          RallyLogger.warning(self, "\tMessage: #{ex.message}")
          raise RecoverableException.new("\tFailed to find the '#{type.to_s.downcase}' artifact", self)
        end
        
        return found_item
      end
#---------------------#
      # find_by_external_id is forced from inheritance
      def find_by_external_id(external_id)
        case @artifact_type.to_s
        when 'testcase'
          uri = "get_cases/#{@tr_project['id']}"
          begin
            uri = "get_cases/#{@tr_project['id']}"
            artifact_array = testrail_send('get', uri)
          rescue Exception => ex
            RallyLogger.warning(self, "EXCEPTION occurred on TestRail API 'send_get(#{uri})':\n")
            RallyLogger.warning(self, "\tMessage: #{ex.message}")
            raise RecoverableException.new("\tFailed to find 'testcases' with populated <ExternalID> field in Project id='#{@tr_project['id']}'", self)
          end 
          
        when 'testrun'
          raise UnrecoverableException.new('Unimplemented logic: find_by_external_id on "testrun"', self)

        when 'testresult'
          raise UnrecoverableException.new('Unimplemented logic: find_by_external_id on "testresult"', self)

        else
          raise UnrecoverableException.new("Unrecognize value for <ArtifactType> '#{@artifact_type.to_s}' (msg5)", self)
        end
        
        matching_artifacts = []
        ids = []
        artifact_array.each do |artifact|
          if artifact[cfsys(@external_id_field)] == external_id
            matching_artifacts.push(artifact)
            ids.push get_id_value(artifact)
          end
        end

        if matching_artifacts.length < 1
          raise RecoverableException.new("No artifacts found with <ExternalID>='#{external_id}'", self)
          return nil
        end
        
        if matching_artifacts.length > 1
          RallyLogger.warning(self, "More than one artifact found with <ExternalID>='#{external_id}' (IDs=#{ids})")
          raise RecoverableException.new("More than one artifact found with <ExternalID>='#{external_id}' (IDs=#{ids})", self)
          return nil
        end

        return matching_artifacts.first
      end
#---------------------#
      def find_new()
        RallyLogger.info(self, "Find new TestRail '#{@artifact_type.to_s.downcase}' objects, created after: '#{Time.at(@run_days_as_unixtime)}'")

        case @artifact_type.to_s.downcase

        when 'testcase'
          matching_artifacts = find_new_testcases()

        when 'testresult'
          matching_artifacts = find_test_results()
          
        else
          raise UnrecoverableException.new("Unrecognized value for <ArtifactType> '#{@artifact_type.to_s.downcase}' (msg3)", self)
        end

        RallyLogger.info(self, "Found '#{matching_artifacts.length}' new TestRail '#{@artifact_type.to_s.downcase}' objects")
        
        return matching_artifacts
      end
#---------------------#
      def find_new_testcases()
        matching_artifacts = []
        case @tr_project_sm
        when 1 # single suite
          # fall thru
          
        when 2 # 1+baselines
          # fall thru
            
        when 3 # 3: multiple suites
          if @all_suites.nil?
            raise UnrecoverableException.new("No suites found? (can't continue)", self)
          end
          # fall thru

        else
          raise UnrecoverableException.new("Invalid value for suite_mode (#{@tr_project_sm})", self)
        end
        
        #RallyLogger.info(self, "Find new TestRail '#{@artifact_type}' objects in suite(s) '#{@all_suite_ids}'")
        
        if @tr_sc.include?('CasesCreated') # Allow user to override default with ENV var
          uri_date = "&created_after=#{@run_days_as_unixtime}"
          str1 = 'created'
        else
          uri_date = "&updated_after=#{@run_days_as_unixtime}" # default search
          str1 = 'updated'
        end
        RallyLogger.info(self, "Find new TestRail 'testcase' objects, in suite(s) '#{@all_suite_ids}', #{str1} after: '#{Time.at(@run_days_as_unixtime)}'")

        @all_suites.each do |next_suite|
          begin
            uri = "get_cases/#{@tr_project['id']}&suite_id=#{next_suite['id']}"
            returned_artifacts = testrail_send('get', uri)
            RallyLogger.debug(self, "Found '#{returned_artifacts.length}' testcases in suite id '#{next_suite['id']}'")
            kept,rejected = filter_out_already_connected(returned_artifacts)
            RallyLogger.debug(self, "Filtered out '#{rejected.length}' of those because they are 'already connected'")
            matching_artifacts = matching_artifacts + kept
          rescue Exception => ex
            RallyLogger.warning(self, "EXCEPTION occurred on TestRail API 'send_get(#{uri})':")
            RallyLogger.warning(self, "\tMessage: #{ex.message}")
            raise UnrecoverableException.new("\tFailed to find new TestRail testcases", self)
          end
        end
        return matching_artifacts
      end
#---------------------#      
      def find_tests_for_run(run_id)
        tests = []
        uri = "get_tests/#{run_id}"
        RallyLogger.info(self, "Doing send_get '#{uri}'")
        begin
          tests = testrail_send('get', uri)
        rescue Exception => ex
          RallyLogger.warning(self, "EXCEPTION occurred on TestRail API 'send_get(#{uri})':")
          RallyLogger.warning(self, "\tMessage: #{ex.message}")
          raise UnrecoverableException.new("\tFailed to find any 'tests' for Run id='#{run_id}'", self)
        end
        return tests
      end
#---------------------#      
      # find and populated related data for plans
      def find_test_plans()
        begin
          uri1 = "get_plans/#{@tr_project['id']}"
          plan_shells = testrail_send('get', uri1)
          plans = []
          plan_shells.each do |plan_shell|
            uri2 = "get_plan/#{plan_shell['id']}"
            plan = testrail_send('get', uri2)
            runs = []
            tests = []
            run_ids = []
              
            entries = plan['entries'] || []
            entries.each do |entry|
              run_shells = entry['runs']
              run_shells.each do |run_shell|
                uri3 = "get_run/#{run_shell['id']}"
                run = testrail_send('get', uri3)
                runs.push(run)
                
                uri4 = "get_tests/#{run_shell['id']}"
                test = testrail_send('get', uri4)
                tests.push(test)
                
                run_ids.push(run_shell['id'])
              end
            end
            plan['runs'] = runs
            plan['tests'] = tests
            plan['run_ids'] = run_ids
            plans.push(plan)
          end
        rescue Exception => ex
          raise UnrecoverableException.new("Failed to find any Test Plans.\n TestRail api returned:#{ex.message}", self)
        end

        return plans
      end
#---------------------#      
      def find_test_results()
        # have to iterate over the runs
        runs, run_ids = find_test_runs()
        #RallyLogger.info(self, "Find new TestRail '#{@artifact_type}' objects for run_id(s) '#{run_ids}'")
        RallyLogger.info(self, "Find new TestRail 'testresult' objects created after '#{Time.at(@run_days_as_unixtime)}' for these '#{run_ids.length}' run_id(s): #{run_ids}")

        test_results = []
        uri_call = 'get_results_for_run'
        uri_date = "&created_after=#{@run_days_as_unixtime}"
        runs.each do |run|
          begin
            run_id = run['id']
            uri = "get_results_for_run/#{run_id}"
            results = testrail_send('get', uri)
            filtered_results,rejected_results = filter_out_already_connected(results)
            test_results = test_results.concat(filtered_results)
            # matching candidates are filtered below...
          rescue Exception => ex
            RallyLogger.warning(self, "EXCEPTION occurred on TestRail API 'send_get(#{uri})':")
            RallyLogger.warning(self, "\tMessage: #{ex.message}")
            raise UnrecoverableException.new("\tFailed to find new Test Results", self)
          end
        end
        
        # pack test result with referenced test and test case
        RallyLogger.debug(self,"Unfiltered test case result set count: '#{test_results.length}'")
        RallyLogger.debug(self,"Filtering out test case results that have an unconnected test case")
        
        filtered_test_results = []
        test_results.each_with_index do |test_result,ndx_test_result|
          if (ndx_test_result+1) % 30 == 0 # show status every now and then...
            RallyLogger.debug(self,"Searched '#{ndx_test_result+1}' so far; continuing search...")
          end
          test = find({ 'id' => test_result['test_id'] }, 'test')
          test_result['_test'] = test  ###  should this be inside the 'if' below?
##----------------------------------------------------------------
## Special code: condition found @ VCE - a testresult has no case associated with it
## use ENV var TR_SysCell=ShowTRvars to simulate condition
          if test.nil?  ||  test['case_id'].to_s.empty?  ||  @tr_sc.include?('ShowTRvars')
            skip_this_one = false
            RallyLogger.warning(self,"TestRail-DataBase-Integrity issue?  (test['id']='#{test['id']}')")
            if test['case_id'].to_s.empty?
              RallyLogger.warning(self,"\tfound Test with no case_id; skipping")
              skip_this_one = true
            end
            if test.nil?
              RallyLogger.warning(self,"\tfound TestResult with no Test; skipping")
              skip_this_one = true
            end
            RallyLogger.warning(self,"test.inspect=#{test.inspect}")
            RallyLogger.warning(self,"test_result.inspect=#{test_result.inspect}")
            next if skip_this_one == true #  (skip this test_result)
          end
##----------------------------------------------------------------
          test_case = find({ 'id' => test['case_id'] }, 'testcase')
          test_result['_testcase'] = test_case
          # we only care about results where the test_case is also connected to Rally
          if !test_case[cfsys(@external_id_field)].nil?
            filtered_test_results.push(test_result)
          end
        end # of 'test_results.each_with_index do |test_result,ndx_test_result|'
        
        return filtered_test_results
      end
#---------------------#      
      def find_test_runs()
        plans = find_test_plans()
        runs = []
        run_ids = []
        plans.each do |plan|
          runs = runs.concat(plan['runs'])
          run_ids = run_ids.concat(plan['run_ids'])
        end
        
#        begin
#          uri = "get_runs/#{@tr_project['id']}"
#          orphan_runs = testrail_send('get', uri)
#          runs = orphan_runs.concat(runs)
#        rescue Exception => ex
#          RallyLogger.warning(self, "EXCEPTION occurred on TestRail API 'send_get(#{uri})':")
#          RallyLogger.warning(self, "\t#{ex.message}")
#          raise UnrecoverableException.new("\tFailed to find any Test Runs", self)
#        end
  
        return runs,run_ids
      end
#---------------------#
      def find_updates(reference_time)
        RallyLogger.info(self, "Find updated TestRail '#{@artifact_type}' objects since '#{reference_time}'")
        unix_time = reference_time.to_i
        artifact_array = []

          case @artifact_type.to_s

        when 'testcase'
          artifact_array = find_updates_testcase(reference_time)

        when 'testrun'
          # Spec tests will looking for the following message
          raise UnrecoverableException.new('Not available for "testrun": find_updates...', self)
            
        when 'testresult'
          # Spec tests will looking for the following message
          raise UnrecoverableException.new('Not available for "testresult": find_updates...', self)

        else
          raise UnrecoverableException.new("Unrecognize value for <ArtifactType> '#{@artifact_type}' (msg6)", self)
        end
        RallyLogger.info(self, "Found '#{artifact_array.length}' updated '#{@artifact_type}' objects in '#{name()}'")

        return artifact_array
      end
#---------------------#
      def find_updates_testcase(reference_time)
        RallyLogger.info(self, "Find updated TestRail '#{@artifact_type}' objects since '#{reference_time}'")
        unix_time = reference_time.to_i
        matching_artifacts = []
        
        @all_suites.each do |next_suite|
          begin
            uri = "get_cases/#{@tr_project['id']}&suite_id=#{next_suite['id']}&updated_after=#{unix_time}"
            result_array = testrail_send('get', uri)
            # throw away those without extid
            result_array.each do |item|
              if item[cfsys(@external_id_field)] != nil
                matching_artifacts.push(item)
              end
            end
          rescue Exception => ex
            RallyLogger.warning(self, "EXCEPTION occurred on TestRail API 'send_get(#{uri})':")
            RallyLogger.warning(self, "\tMessage: #{ex.message}")
            raise UnrecoverableException.new("Failed trying to find 'testcases' for update in Project id='#{@tr_project['id']}', Suite id='#{next_suite['id']}', updated_after='#{unix_time}'", self)
          end
        end

        return matching_artifacts
      end
#---------------------#
      def get_all_sections()
        case @tr_project_sm
          when 1 # single suite
          when 2 # 1+baselines
            @all_suites = [{'id' => @tr_project['id']}]
          when 3 # 3: multiple suites
            if @all_suites.nil?
              raise UnrecoverableException.new("No suites found? (can't continue)", self)
            end
          else
            raise UnrecoverableException.new("Invalid value for suite_mode (#{@tr_project_sm})", self)
        end
        @all_sections = Array.new
        @all_suites.each do |next_suite|
          uri = "get_sections/#{@tr_project['id']}&suite_id=#{next_suite['id']}"
          begin  
            sections = testrail_send('get', uri)
          rescue Exception => ex
            RallyLogger.warning(self, "EXCEPTION occurred on TestRail API 'send_get(#{uri})'::")
            RallyLogger.warning(self, "\t#{ex.message}")
          end
          @all_sections.push(sections)
        end
        return @all_sections.first || {}
      end      
#---------------------#
      def get_all_suites()
        uri = "get_suites/#{@tr_project['id']}"
        @all_suites = testrail_send('get', uri)
        return @all_suites
      end
#---------------------#
#      def get_default_section_id()
#RallyLogger.debug(self,"JPKdebug: #{@tr_project['id']}")
#RallyLogger.debug(self,"JPKdebug: get_sections/#{@tr_project['id']}")
#        begin
#          returned_artifacts = testrail_send('get', "get_sections/#{@tr_project['id']}")
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
      def get_value(artifact,field_name)
        return artifact["#{field_name.downcase}"]
      end
#---------------------#
      def pre_create(int_work_item)
        return int_work_item
      end
#---------------------#
#require 'byebug';byebug
      def testrail_send(*args)
        
        # Used to check that retry logic was working.
        #require 'SecureRandom'
        #unique_key = SecureRandom.base64

        func, uri, fields = *args
        @tr_api_retry_current ||= 0        
        begin
          current_time = Time.now.to_f
          time_since_previous_call = current_time - @tr_api_time_of_previous_call
          if @tr_api_time_of_first_call == -1.0
            time_since_previous_call      = 0.0
            @tr_api_time_of_first_call    = current_time
            @tr_api_time_of_previous_call = current_time
          end
          str1 =        " @ %8.6fms"      % [current_time - @tr_api_time_of_first_call]
          str1 = str1 + "  prev %8.6fms"  % [@tr_api_time_of_previous_call - @tr_api_time_of_first_call]
          str1 = str1 + "  elap %8.6fms)" % [time_since_previous_call]
          #str1 = str1 + "  key %s"        % [unique_key]
          RallyLogger.debug(self, "TestRail-API #{func}" + str1)

          case func
          #---------------------##---------------------#
          when 'get'
            if args.length != 2
              raise UnrecoverableException.new("On TestRail API call, expected '2' args, got '#{args.length}'", self)
            end  
            results = @testrail.send_get(uri)
          #---------------------##---------------------#
          when 'post'
            if (args.length != 3)
              raise UnrecoverableException.new("On TestRail API call, expected '3' args, got '#{args.length}'", self)
            end
            results = @testrail.send_post(uri, fields)
          #---------------------##---------------------#
          else
            raise UnrecoverableException.new("TestRail API call must be either 'get' or 'post'; got '#{func}'", self)
          end
        rescue Exception => ex
          @tr_api_retry_current += 1
          good_msg = 'TestRail API returned HTTP 429'
          if (@tr_api_retry_current < @tr_api_retry_maximum) && ex.message.start_with?(good_msg)
            #RallyLogger.warning(self, "TestRail-API-call: INVOKING RETRY #{@tr_api_retry_current} of #{@tr_api_retry_maximum}; key='#{unique_key}'...")
            RallyLogger.warning(self, "TestRail-API-call: INVOKING RETRY #{@tr_api_retry_current} of #{@tr_api_retry_maximum}...")
            @tr_api_time_of_previous_call = current_time
            retry
          else
            case func
            when 'get'
              RallyLogger.warning(self, "EXCEPTION occurred on TestRail API 'send_get(arg1)':")
            when 'post'
              RallyLogger.warning(self, "EXCEPTION occurred on TestRail API during 'send_post(arg1, arg2)'")
              RallyLogger.warning(self, "\targ2: '#{fields})'")
            else
              @tr_api_retry_current = nil
              raise UnrecoverableException.new("Internal Error: TestRail API call must be either 'get' or 'post'; got '#{func}'", self)
            end
          end
          RallyLogger.warning(self, "\targ1: '#{uri}'")
          RallyLogger.warning(self, "\tmsg : '#{ex.message}'")
          auth_msg = 'TestRail API returned HTTP 401'
          if ex.message.start_with?(auth_msg)
            RallyLogger.warning(self, "\tusername: '#{@testrail.user}'")
            RallyLogger.warning(self, "\tpassword: '********'")
          end
          RallyLogger.warning(self, "\ttime since previous API call: %8.6f"%[time_since_previous_call])
          RallyLogger.warning(self, "\t@tr_api_retry_current='#{@tr_api_retry_current}'")
          RallyLogger.warning(self, "\t@tr_api_retry_maximum='#{@tr_api_retry_maximum}'")
          @tr_api_retry_current = nil
          raise
        else
          @tr_api_time_of_previous_call = current_time
          if @tr_api_retry_current > @tr_api_max_try_count
            @tr_api_max_try_count = @tr_api_retry_current
          end
        end
        @tr_api_retry_current = nil
        return results
      end
#---------------------#
      def update_external_id_fields(artifact, external_id, end_user_id, item_link)
        if @artifact_type.to_s.downcase == "testresult"
          return artifact
        end
        
        new_fields = {}
        if !external_id.nil?
          sys_name = cfsys(@external_id_field)
          new_fields[sys_name] = external_id
          RallyLogger.debug(self, "Updating TestRail item <ExternalIDField>: '#{sys_name}' to '#{external_id}'")
        end

        # Rally gives us a full '<a href=' tag
        if !item_link.nil?
          url_only = item_link.gsub(/.* href=["'](.*?)['"].*$/, '\1')
          if !@external_item_link_field.nil?
            sys_name = cfsys(@external_item_link_field)
            new_fields[sys_name] = url_only
            RallyLogger.debug(self, "Updating TestRail item <CrosslinkUrlField>: '#{sys_name}' to '#{url_only}'")
          end
        end

        if !@external_end_user_id_field.nil?
          sys_name = cfsys(@external_end_user_id_field)
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
          uri = "update_case/#{artifact['id']}"
          updated_item = testrail_send('post', uri, all_fields)

        when 'testrun'
          all_fields = artifact
          all_fields.merge!(new_fields)
          uri = "update_run/#{artifact['id']}"
          updated_item = testrail_send('post', uri, all_fields)
          
        when 'testresult'
          raise UnrecoverableException.new('Unimplemented logic: update_internal on "testresult"...', self)

        else
          raise UnrecoverableException.new("Unrecognize value for <ArtifactType> '#{@artifact_type.to_s.downcase}' (msg7)", self)
        end
        return updated_item
      end
#---------------------#
      def validate
        status_of_all_fields = true  # Assume all fields passed
        
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
