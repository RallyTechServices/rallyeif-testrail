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
      attr_accessor :project,  :section_id
      
      #
      # Global info that will be obtained from the TestRail system.
      #
      @testrail           = '' # The connecton packet used to make request.
      @tr_project         = {} # Information about project in config file.
      @all_suites         = {} # All suites in the project.
      @all_sections       = {} # All sections in the project
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
        @url       = XMLUtils.get_element_value(config, self.conn_class_name.to_s, "Url")
        @project   = XMLUtils.get_element_value(config, self.conn_class_name.to_s, "Project")
        # yes, it's weird to put a field name from a Rally artifact into the other connection
        # but this keeps us from overriding/monkey-patching the Rally connection class
        @rally_story_field_for_plan_id = XMLUtils.get_element_value(config, self.conn_class_name.to_s, "RallyStoryFieldForPlanID", false)
        @section_id = nil
        @cfg_suite_ids = XMLUtils.get_element_value(config, self.conn_class_name.to_s, "SuiteIDs", false)
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
        #            (not necessary to have them all, but we have to find ours anyway)
        #
        uri = 'get_projects'
        all_projects = @testrail.send_get(uri)
        
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


        # Build section info...
        @tr_section_ids = Array.new
        @all_sections = get_all_sections()
        RallyLogger.debug(self, "Found '#{@all_sections.length}' sections")
        @all_sections.each do |next_section|
          RallyLogger.debug(self, "\tid='#{next_section['id']}', suite_id='#{next_section['suite_id']}' name='#{next_section['name']}'")
          @tr_section_ids.push(next_section['id'])
        end

          
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
                    'Multi-select'] # 12
        case @artifact_type.to_s
        when 'testcase'
          begin
            uri = 'get_case_fields'
            cust_fields = @testrail.send_get(uri)
          rescue Exception => ex
            RallyLogger.warning(self, "EXCEPTION occurred on TestRail API 'send_get(#{uri})':")
            RallyLogger.warning(self, "\t#{ex.message}")
            raise UnrecoverableException.new("\tFailed to retrieve Test Case custom field names", self)
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
        
        when 'testsuite'
          #

        when 'testsection'
          #

        when 'testresult'
          begin
            uri = 'get_result_fields'
            cust_fields = @testrail.send_get(uri)
          rescue Exception => ex
            RallyLogger.warning(self, "EXCEPTION occurred on TestRail API 'send_get(#{uri})':")
            RallyLogger.warning(self, "\t#{ex.message}")
            raise UnrecoverableException.new("\tFailed to retrieve Test Result custom field names", self)
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
          RallyLogger.error(self, "Unrecognize value for <ArtifactType> '#{@artifact_type}' (msg1)")
        end


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
        when 'testrun'
        when 'testsuite'
        when 'testsection'
        
        else
          RallyLogger.error(self, "Unrecognized value for <ArtifactType> '#{@artifact_type}' (msg2)")
        end


        #
        # USER INFO:  Request info for the user listed in config file
        #
        begin
          uri = "get_user_by_email&email=#{@user}"
          @tr_user_info = @testrail.send_get(uri)
          RallyLogger.debug(self, "User information retrieve successfully for '#{@user}'")
        rescue Exception => ex
          RallyLogger.warning(self, "EXCEPTION occurred on TestRail API 'send_get(#{uri})':")
          RallyLogger.warning(self, "\t#{ex.message}")
          raise UnrecoverableException.new("\tFailed to retrieve information for <User> '#{@user}'", self)
        end
        
        return @testrail

      end # 'def connect()'
#---------------------#      
      def add_run_to_plan(testrun,testplan)
        RallyLogger.debug(self, "Preparing to add testrun: '#{testrun}'")
        RallyLogger.debug(self, "             to testplan: '#{testplan}'")
        begin
          uri = "add_plan_entry/#{testplan['id']}"
          extra_fields = { 'suite_id' => testrun['suite_id'], 'runs' => [testrun] }
          new_plan_entry = @testrail.send_post(uri, extra_fields)
          RallyLogger.debug(self, "New plan entry: '#{new_plan_entry}'")
        rescue Exception => ex
          RallyLogger.warning(self, "EXCEPTION occurred on TestRail API 'send_post(#{uri}, #{extra_fields})':")
          RallyLogger.warning(self, "\t#{ex.message}")
          raise UnrecoverableException.new("\tFailed to add TestRun '#{testrun['id']}' to TestPlan '#{testplan['id']}'", self)
        end
        return new_plan_entry
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
            RallyLogger.debug(self,"Preparing to create a TestRail '#{@artifact_type}' in Section '#{section_id}'")
            uri = "add_case/#{section_id}"
            new_item = @testrail.send_post(uri, int_work_item)
            gui_id = 'C' + new_item['id'].to_s # How it appears in the GUI
            extra_info = ''
            #RallyLogger.debug(self,"We just created TestRail '#{@artifact_type}' object #{gui_id}")
            
          when 'testrun'
            suite_id = int_work_item['suite_id']
            RallyLogger.debug(self,"Preparing to create a TestRail '#{@artifact_type}' in Suite 'S#{suite_id}'")
            uri = "add_run/#{@tr_project['id']}&suite_id=#{suite_id}"
            new_item = @testrail.send_post(uri, int_work_item)
            gui_id = 'R' + new_item['id'].to_s # How it appears in the GUI
            extra_info = ''
            
          when 'testplan'
            RallyLogger.debug(self,"Preparing to create a TestRail '#{@artifact_type}'")
            uri = "add_plan/#{@tr_project['id']}"
            new_item = @testrail.send_post(uri, int_work_item)
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
            new_item = @testrail.send_post(uri, int_work_item)
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
            new_item = @testrail.send_post(uri, int_work_item)
                  # Returns:
            gui_id = new_item['id'].to_s # How it appears in the GUI
            extra_info = ''
            
          when 'testresult'
            # Hardcode these until we understand more...
            run_id  = 1
            case_id = 2

            run_id = int_work_item['run_id'] || run_id
            case_id = int_work_item['case_id'] || case_id
            RallyLogger.debug(self,"Preparing to create a TestRail '#{@artifact_type}' for run_id='R#{run_id}', case_id='T#{case_id}'")
            uri = "add_result_for_case/#{run_id}/#{case_id}"
            new_item = @testrail.send_post(uri, int_work_item)
            gui_id = "(id='#{new_item['id']}' test_id='#{new_item['test_id']}')"
            extra_info = ''
            
          else
            raise UnrecoverableException.new("Unrecognized value for <ArtifactType> '#{@artifact_type}' (msg2)", self)
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
            retval = @testrail.send_post(uri,nil)
          when 'testrun'
            uri = "delete_run/#{item['id']}"
            retval = @testrail.send_post(uri,nil)
          when 'testplan'
            uri = "delete_plan/#{item['id']}"
            retval = @testrail.send_post(uri,nil)
          when 'testsuite'
            uri = "delete_suite/#{item['id']}"
            retval = @testrail.send_post(uri,nil)
          when 'testsection'
            # Don't try to delete it unless it exist.
            get_all_sections().each do |next_section|
              uri = nil
              if next_section['id'] == item['id']
                uri = "delete_section/#{item['id']}"
                retval = @testrail.send_post(uri,nil)
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
            raise UnrecoverableException.new("Unrecognize value for <ArtifactType> '#{@artifact_type}' (msg2)", self)
          end
        rescue Exception => ex
          RallyLogger.warning(self, "EXCEPTION occurred on TestRail API 'send_post(#{uri}, nil)':\n")
          RallyLogger.warning(self, "\t#{ex.message}")
          raise RecoverableException.new("\tFailed to delete '#{@artifact_type}'; id='#{item['id']}'", self)
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
          raise UnrecoverableException.new("Unrecognize value for <ArtifactType> '#{@artifact_type}' (msg3)", self)
        end
        
        return true
      end
#---------------------#
      def find(item, type=@artifact_type)
        begin
          case type.to_s.downcase
          when 'testcase'
            uri = "get_case/#{item['id']}"
            found_item = @testrail.send_get(uri)
          
          when 'test'
            uri = "get_test/#{item['id']}"
            found_item = @testrail.send_get(uri)
                      
          when 'testrun'
            raise UnrecoverableException.new('Unimplemented logic: find on "testrun"...', self)
          
          when 'testresult'
            raise UnrecoverableException.new('Unimplemented logic: find on "testresult"...', self)
          
          else
            raise UnrecoverableException.new("Unrecognize value for <ArtifactType> '#{type}' (msg4)", self)
          end
        rescue Exception => ex
          RallyLogger.warning(self, "EXCEPTION occurred on TestRail API 'send_get(#{uri})':\n")
          RallyLogger.warning(self, "\t#{ex.message}")
          raise RecoverableException.copy("\tFailed to find the '#{type}' artifact", self)
        end
        
        return found_item
      end
#---------------------#
      # find_by_external_id is forced from inheritance
      def find_by_external_id(external_id)
        case @artifact_type.to_s
        when 'testcase'
          begin
            uri = "get_cases/#{@tr_project['id']}"
            artifact_array = @testrail.send_get(uri)
          rescue Exception => ex
            RallyLogger.warning(self, "EXCEPTION occurred on TestRail API 'send_get(#{uri})':\n")
            RallyLogger.warning(self, "\t#{ex.message}")
            raise RecoverableException.new("\tFailed to find testcases with populated <ExternalID> field", self)
          end 
          
        when 'testrun'
          raise UnrecoverableException.new('Unimplemented logic: find_by_external_id on "testrun"', self)

        when 'testresult'
          raise UnrecoverableException.new('Unimplemented logic: find_by_external_id on "testresult"', self)

        else
          raise UnrecoverableException.new("Unrecognize value for <ArtifactType> '#{@artifact_type}' (msg5)", self)
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

        case @artifact_type.to_s.downcase
        when 'testcase'
          matching_artifacts = find_new_testcases()
               
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
        
        RallyLogger.info(self, "Find new TestRail '#{@artifact_type}' objects in suite(s) '#{@all_suite_ids}'")
        @all_suites.each do |next_suite|
          begin
             uri = "get_cases/#{@tr_project['id']}&suite_id=#{next_suite['id']}"
             returned_artifacts = @testrail.send_get(uri)
             RallyLogger.debug(self, "Found '#{returned_artifacts.length}' testcases in suite id '#{next_suite['id']}'")
             matching_artifacts = matching_artifacts + filter_out_already_connected(returned_artifacts)
           rescue Exception => ex
             RallyLogger.warning(self, "EXCEPTION occurred on TestRail API 'send_get(#{uri})':")
             RallyLogger.warning(self, "\t#{ex.message}")
             raise UnrecoverableException.new("\tFailed to find new TestRail testcases", self)
           end
        end
        return matching_artifacts
      end
#---------------------#
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
#          orphan_runs = @testrail.send_get(uri)
#          runs = orphan_runs.concat(runs)
#        rescue Exception => ex
#          RallyLogger.warning(self, "EXCEPTION occurred on TestRail API 'send_get(#{uri})':")
#          RallyLogger.warning(self, "\t#{ex.message}")
#          raise UnrecoverableException.new("\tFailed to find any Test Runs", self)
#        end
  
        return runs,run_ids
      end
#---------------------#      
      def find_test_for_run(run_id)
        tests = []
        uri = "get_tests/#{run_id}"
        RallyLogger.info(self, "Doing send_get '#{uri}'")
        begin
          tests = @testrail.send_get(uri)
        rescue Exception => ex
          RallyLogger.warning(self, "EXCEPTION occurred on TestRail API 'send_get(#{uri})':")
          RallyLogger.warning(self, "\t#{ex.message}")
          raise UnrecoverableException.new("\tFailed to find any Tests", self)
        end
        return tests
      end
#---------------------#      
      # find and populated related data for plans
      def find_test_plans()
        begin
          uri1 = "get_plans/#{@tr_project['id']}"
          plan_shells = @testrail.send_get(uri1)
          plans = []
          plan_shells.each do |plan_shell|
            uri2 = "get_plan/#{plan_shell['id']}"
            plan = @testrail.send_get(uri2)
            runs = []
            tests = []
            run_ids = []
              
            entries = plan['entries'] || []
            entries.each do |entry|
              run_shells = entry['runs']
              run_shells.each do |run_shell|
                uri3 = "get_run/#{run_shell['id']}"
                run = @testrail.send_get(uri3)
                runs.push(run)
                
                uri4 = "get_tests/#{run_shell['id']}"
                test = @testrail.send_get(uri4)
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
        RallyLogger.info(self, "Find new TestRail '#{@artifact_type}' objects for run_id(s) '#{run_ids}'")
        
        test_results = []
        runs.each do |run|
          begin
            run_id = run['id']
            uri = "get_results_for_run/#{run_id}"
            results = @testrail.send_get(uri)
            filtered_results = filter_out_already_connected(results)
            test_results = test_results.concat(filtered_results)
            # matching candidates are filtered below...
          rescue Exception => ex
            RallyLogger.warning(self, "EXCEPTION occurred on TestRail API 'send_get(#{uri})':")
            RallyLogger.warning(self, "\t#{ex.message}")
            raise UnrecoverableException.new("\tFailed to find new Test Results", self)
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
          artifact_array = find_updates_testcase(reference_time)
        when 'testrun'
          raise UnrecoverableException.new('Not available for "testrun": find_updates..', self)
            
        when 'testresult'
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
            result_array = @testrail.send_get(uri)
            # throw away those without extid
            result_array.each do |item|
              if item["custom_#{@external_id_field.downcase}"] != nil
                matching_artifacts.push(item)
              end
            end
          rescue Exception => ex
            RallyLogger.warning(self, "EXCEPTION occurred on TestRail API 'send_get(#{uri})':")
            RallyLogger.warning(self, "\t#{ex.message}")
            raise UnrecoverableException.new("Failed trying to find testcases for update", self)
          end
        end

        return matching_artifacts
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
            sections = @testrail.send_get(uri)
          rescue Exception => ex
            RallyLogger.warning(self, "EXCEPTION occurred on TestRail API 'send_get(#{uri})':")
            RallyLogger.warning(self, "\t#{ex.message}")
          end
          @all_sections.push(sections)
        end
        return @all_sections.first || {}
      end      
#---------------------#
      def get_all_suites()
        uri = "get_suites/#{@tr_project['id']}"
        @all_suites = @testrail.send_get(uri)
        return @all_suites
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
          uri = "update_case/#{artifact['id']}"
          updated_item = @testrail.send_post(uri, all_fields)

        when 'testrun'
          all_fields = artifact
          all_fields.merge!(new_fields)
          uri = "update_run/#{artifact['id']}"
          updated_item = @testrail.send_post(uri, all_fields)
          
        when 'testresult'
          raise UnrecoverableException.new('Unimplemented logic: update_internal on "testresult"...', self)

        else
          raise UnrecoverableException.new("Unrecognize value for <ArtifactType> '#{@artifact_type}' (msg7)", self)
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
