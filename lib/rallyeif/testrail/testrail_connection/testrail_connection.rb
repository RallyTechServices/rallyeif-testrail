# Copyright 2001-2014 Rally Software Development Corp. All Rights Reserved.

require 'rallyeif-wrk'
require './testrail-api-master/ruby/testrail.rb'

RecoverableException   = RallyEIF::WRK::RecoverableException if not defined?(RecoverableException)
UnrecoverableException = RallyEIF::WRK::UnrecoverableException
RallyLogger            = RallyEIF::WRK::RallyLogger
XMLUtils               = RallyEIF::WRK::XMLUtils

module RallyEIF
  module WRK
    
    VALID_TESTRAIL_ARTIFACTS = ['testcase']
                          
    class TestRailConnection < Connection

      attr_reader   :testrail
      attr_accessor :project
      
      #
      # Global info that will be obtained from the TestRail system.
      #
      @testrail           = '' # The connecton packet used to make request.
      @tr_project_tc      = {} # Information about project in config file.
      @tr_cust_fields_tc  = {} # Hash of custom fields on test case.
      @tr_fields_tc       = {} # Hash of standard fields on test case.
      @tr_user_info       = {} # TestRail information about user in config file.
      
      def initialize(config=nil)
        super()
        read_config(config) if !config.nil?
      end
      
      def read_config(config)
        super(config)
        @url     = XMLUtils.get_element_value(config, self.conn_class_name.to_s, "Url")
        @project = XMLUtils.get_element_value(config, self.conn_class_name.to_s, "Project")
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
              RallyLogger.info(self,"Found project:")
            end
            RallyLogger.info(self,"\tid:#{proj['id']}  name:#{proj['name']}  url:#{proj['url']}   is_completed:#{proj['is_completed']}")
          end
        end
        if found_projects.length != 1
          raise UnrecoverableException.new("Found '#{found_projects.length}' projects named '#{@project}'; the connector needs one and only one", self)
        end
        
        
        #
        # CUSTOM FIELDS:  Build a hash of TestCase custom fields.  Each entry:
        #   {'system_name' => ['name', 'label', 'type_id', [ProjIDs]}
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
          @tr_cust_fields_tc[item['system_name']] =  [item['name'],
                                                      item['label'],
                                                      item['type_id'],
                                                      pids]
        end


        #
        # STANDARD FIELDS:  Build hash of TestCase standard fields
        #                   (done manually since there is no API method to get them).
        #                  Field-name          Type (1=String, 2=Integer)
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
#---------------------#
      def create_internal(int_work_item)
        RallyLogger.debug(self,"Preparing to create a TestRail: '#{@artifact_type}'")
        begin
          case @artifact_type
          when :testcase
            new_item = @testrail.send_post('add_case/1', int_work_item)
          else
            raise UnrecoverableException.new("Unrecognize value for <ArtifactType> ('#{@artifact_type}')", self)
          end
        rescue RuntimeError => ex
          raise RecoverableException.copy(ex, self)
        end
        RallyLogger.debug(self,"Created #{@artifact_type} #{new_item['id']}")
        return new_item
      end
#---------------------#
      def delete(item)
        case @artifact_type.to_s.downcase
        when 'testcase'
          retval = @testrail.send_post("delete_case/#{item['id']}",nil)
        else
          raise UnrecoverableException.new("Unrecognize value for <ArtifactType> '#{@artifact_type}')", self)
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
              RallyLogger.error(self, "TestRail field '#{field_name.to_s}' is not a valid field name for object type '#{@artifact_type}'")
              RallyLogger.debug(self, "Available fields: #{@tr_fields_tc}, #{@tr_cust_fields_tc}")
              return false
            end
          end
        else
          raise UnrecoverableException.new("Unrecognize value for <ArtifactType> ('#{@artifact_type}')", self)
        end
        
        return true
      end
#---------------------#
      def find(item)
        case @artifact_type.to_s.downcase
        when 'testcase'
          found_item = @testrail.send_get("get_case/#{item['id']}")
        else
          raise UnrecoverableException.new("Unrecognize value for <ArtifactType> '#{@artifact_type})", self)
        end
        return found_item
      end
#---------------------#
      # find_by_external_id is forced from inheritance
      def find_by_external_id(external_id)
        begin
          query = "SELECT Id,Subject FROM #{@artifact_type} WHERE #{@external_id_field} = '#{external_id}'"
          RallyLogger.debug(self, " Using SOQL query: #{query}")
          artifact_array = find_by_query(query)
        rescue Exception => ex
          raise UnrecoverableException.new("Failed search using query: #{query}.\n TestRail api returned:#{ex.message}", self)
          raise UnrecoverableException.copy(ex,self)
        end
        if artifact_array.length == 0
          raise RecoverableException.new("No artifacts returned on query: '#{query}'", self)
          return nil
        end
        if artifact_array.length > 1
          RallyLogger.warning(self, "More than one artifact returned on query: '#{query}'")
          raise RecoverableException.new("More than one artifact returned on query: '#{query}'", self)
        end
        return artifact_array.first
      end
#---------------------#
      def find_by_query(string)
        unpopulated_items = @testrail.query(string)
        populated_items = []
        unpopulated_items.each do |item|
          populated_items.push(@artifact_type.find(item['id']))
        end
        return populated_items
      end
#---------------------#
      def find_new()
        RallyLogger.info(self, "Find New TestRail '#{@artifact_type}' objects")
        artifact_array = []
        case @artifact_type.to_s
        when 'testcase'
          begin

# ToDo: Add project, milestone, section, etc
            
            artifact_array = @testrail.send_get("get_cases/1")
          rescue Exception => ex
            raise UnrecoverableException.new("Failed to find new testcases.\n TestRail api returned:#{ex.message}", self)
          end  
        else
          raise UnrecoverableException.new("Unrecognize value for <ArtifactType> (#{@artifact_type})", self)
        end

        #
        # get only the new ones
        #
        returned_artifacts = []
        artifact_array.each do |artifact|
          if artifact["custom_#{@external_id_field.downcase}"].nil?
            returned_artifacts.push(artifact)
          end
        end
        RallyLogger.info(self, "Found '#{returned_artifacts.length}' new TestRail '#{@artifact_type}' objects")
        
        return returned_artifacts
      end
#---------------------#
      def find_updates(reference_time)
        RallyLogger.info(self, "Find Updated TestRail objects of type '#{@artifact_type}' since '#{reference_time}' (class=#{reference_time.class})")
        artifact_array = []
        begin
          query = "SELECT Id,Subject FROM #{@artifact_type} #{get_SOQL_where_for_updates()}"
          RallyLogger.debug(self, " Using SOQL query: #{query}")
          artifact_array = find_by_query(query)
        rescue Exception => ex
          raise UnrecoverableException.new("Failed search using query: #{query}.\n TestRail api returned:#{ex.message}", self)
        end
        
        RallyLogger.info(self, "Found '#{artifact_array.length}' updated '#{@artifact_type}' objects in '#{name()}'.")

        return artifact_array
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
      def get_value(artifact,field_name)
        return artifact["#{field_name.downcase}"]
      end
#---------------------#
      def pre_create(int_work_item)
        return int_work_item
      end
#---------------------#
      def update_internal(artifact, new_fields)
        #artifact.update_attributes int_work_item
        case @artifact_type.to_s.downcase
        when 'testcase'
          all_fields = artifact
          all_fields.merge!(new_fields)
          updated_item = @testrail.send_post("update_case/#{artifact['id']}", all_fields)
        else
          raise UnrecoverableException.new("Unrecognize value for <ArtifactType>: '#{@artifact_type}'", self)
        end
        return updated_item
      end
#---------------------#
      def update_external_id_fields(artifact, external_id, end_user_id, item_link)
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
          RallyLogger.debug(self, "Updating TestRail item <ExternalEndUserIDField>: '#{sys_name}' to '#{@end_user_id}'")
        end
        
        updated_item = update_internal(artifact, new_fields)
        return updated_item
      end
#---------------------#
      def validate
        status_of_all_fields = true  # Assume all fields passed
        
        sys_name = 'custom_' + @external_id_field.to_s.downcase
        if !field_exists?(@external_id_field)
          status_of_all_fields = false
          RallyLogger.error(self, "TestRail <ExternalIDField> '#{sys_name}' does not exist")
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