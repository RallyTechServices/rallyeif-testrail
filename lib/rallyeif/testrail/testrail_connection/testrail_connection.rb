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

      attr_reader :testrail, :project
      
      #
      # Global info that will be obtained from the TestRail system.
      #
      @testrail     = '' # The connecton packet used to make request.
      @tr_user_info = '' # TestRail information about user in config file.
      @tr_fields_tc = '' # Hash of test case object fields.
      
      def initialize(config=nil)
        super()
        read_config(config) if !config.nil?
      end
      
      def read_config(config)
        super(config)
        @url = XMLUtils.get_element_value(config, self.conn_class_name.to_s, "Url")
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
        # Request info for the user listed in config file
        #
        begin
          @tr_user_info = @testrail.send_get("get_user_by_email&email=#{@user}")
          RallyLogger.debug(self, "User information retrieve successfully for '#{@user}'")
        rescue Exception => ex
          raise UnrecoverableException.new("Cannot retrieve information for user '#{@user}'.\n TestRail api returned:#{ex.message}", self)
        end
        
        #
        # Build a hash of TestRail projects
        #
        ####code here
        
        #
        # Build hash of real fields or add to next fields
        #
        @tr_fields_tc = {'title' => ['title', 'title', 1, 'String', nil],
                         'id'    => ['id', 'id', 2, 'Integer', nil]
                        }
          
        #
        # Build a hash of custom fields: {'system_name' => ['name', 'label', 'type_id', 'String of type-id'], global???}
        #
        begin   
          tmp = @testrail.send_get('get_case_fields')
        rescue Exception => ex
          raise UnrecoverableException.new("Cannot retrieve information for user '#{@user}'.\n TestRail api returned:#{ex.message}", self)
        end
        
        @tr_cust_fields_tc = {}
        str_types = ['',             # 0
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
                     '?Unknown?',    # 11
                     'Multi-select', # 12
                    ]
        tmp.each do |item|
          # Is this custom field defined for the current project?
          if item['configs'][0].to_hash['context']['is_global'] == true
            pids = nil
          else
            pids = item['configs'][0].to_hash['context']['project_ids']
          end
          @tr_cust_fields_tc[item['system_name']] =  [item['name'],
                                                      item['label'],
                                                      item['type_id'],
                                                      str_types[item['type_id']],
                                                      pids]
        end
        
        return @testrail
      end
#---------------------#
      def create_internal(int_work_item)
        RallyLogger.debug(self,"Preparing to create one TestRail: '#{@artifact_type}'")
        begin
          case @artifact_type
          when :testcase
            # Create a TestRail TestCase
            #tc_fields  = {
              #'title'         => 'Time-' + Time.now.strftime("%Y-%m-%d_%H:%M:%S") + '-' + Time.now.usec.to_s,
              #'type_id'       => 6,
              #'priority_id'   => 5,
              #'estimate'      => '3m14s',
              #'milestone_id'  => 1,
              #'refs'          => '',
            #}
            new_item = @testrail.send_post('add_case/1', int_work_item)
            new_item.merge!({'TypeOfArtifact'=>'testcase'})
          else
            raise UnrecoverableException.new("Unrecognize value for @artifact_type ('#{@artifact_type}')", self)
          end
        rescue RuntimeError => ex
          raise RecoverableException.copy(ex, self)
        end
        RallyLogger.debug(self,"Created #{@artifact_type} #{new_item['id']}")
        return new_item
      end
#---------------------#
      def delete(item)
        case item['TypeOfArtifact']
        when 'testcase'
          retval = @testrail.send_post("delete_case/#{item['id']}",nil)
        else
          raise UnrecoverableException.new("Unrecognize value for item['TypeOfArtifact'] ('#{item['TypeOfArtifact']}')", self)
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
          raise UnrecoverableException.new("Unrecognized <ArtifactType> value of '#{@artifact_type}'", self)
        end
        
        return true
      end
#---------------------#
      def find(item)
        case item['TypeOfArtifact']
        when 'testcase'
          found_item = @testrail.send_get("get_case/#{item['id']}")
          found_item.merge!({'TypeOfArtifact'=>'testcase'})
        else
          raise UnrecoverableException.new("Unrecognize value for TypeOfArtifact (#{item['TypeOfArtifact']})", self)
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
        begin
          query = "SELECT Id FROM #{@artifact_type} #{get_SOQL_where_for_new()}"
          RallyLogger.debug(self, " Using SOQL query: #{query}")
          artifact_array = find_by_query(query)
        rescue Exception => ex
          raise UnrecoverableException.new("Failed search using query: #{query}.\n TestRail api returned:#{ex.message}", self)
          raise UnrecoverableException.copy(ex,self)
        end
        
        RallyLogger.info(self, "Found '#{artifact_array.length}' new '#{@artifact_type}' objects in '#{name()}'.")
        return artifact_array
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
          raise UnrecoverableException.copy(ex,self)
        end
        
        RallyLogger.info(self, "Found '#{artifact_array.length}' updated '#{@artifact_type}' objects in '#{name()}'.")

        return artifact_array
      end
#---------------------#
      # This method will hide the actual call of how to get the id field's value
      def get_id_value(artifact)
        RallyLogger.debug(self,"#{artifact.attributes}")
        return artifact["id"]
      end
#---------------------#
      def get_object_link(artifact)
        # We want:  "<a href='https://<TestRail server>/<Artifact ID>'>link</a>"
        linktext = artifact[@id_field] || 'link'
        it = "<a href='https://#{@url}/#{artifact['id']}'>#{linktext}</a>"
        return it
      end
#---------------------#
      def pre_create(int_work_item)
        return int_work_item
      end
#---------------------#
      def update_internal(artifact, new_fields)
        #artifact.update_attributes int_work_item
        case artifact['TypeOfArtifact']
        when 'testcase'
          all_fields = artifact
          all_fields.merge!(new_fields)
          all_fields.merge!({'TypeOfArtifact'=>'testcase'})
          updated_item = @testrail.send_post("update_case/#{artifact['id']}", all_fields)
        else
          raise UnrecoverableException.new("Unrecognize value for TypeOfArtifact: '#{artifact['TypeOfArtifact']}'", self)
        end
        return updated_item
      end
#---------------------#
      def update_external_id_fields(artifact, external_id, end_user_id, item_link)
        new_fields = {}
        if !external_id.nil?
          sys_name = 'custom_' + @external_id_field.to_s.downcase
          new_fields[sys_name] = external_id
          RallyLogger.debug(self, "Updating TestRail item <ExternalIDField> field '#{sys_name}' to '#{external_id}'")
        end

        # Rally gives us a full '<a href=' tag
        if !item_link.nil?
          url_only = item_link.gsub(/.* href=["'](.*?)['"].*$/, '\1')
          if !@external_item_link_field.nil?
            sys_name = 'custom_' + @external_item_link_field.to_s.downcase
            new_fields[sys_name] = url_only
            RallyLogger.debug(self, "Updating TestRail item <CrosslinkUrlField> field (#{sys_name}) to '#{url_only}'")
          end
        end

        if !@external_end_user_id_field.nil?
          sys_name = 'custom_' + @external_end_user_id_field.to_s.downcase
          new_fields[sys_name] = end_user_id
          RallyLogger.debug(self, "Updating TestRail item <ExternalEndUserIDField> field (#{sys_name}) to '#{@end_user_id}'")
        end
        
        updated_item = update_internal(artifact, new_fields)
        return updated_item
      end
#---------------------#
      def validate
        status_of_all_fields = true  # Assume all fields passed
        
        sys_name = 'custom_' + @external_id_field.to_s.downcase
        if !field_exists?(sys_name)
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