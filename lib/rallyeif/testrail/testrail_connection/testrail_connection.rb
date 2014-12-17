# Copyright 2001-2014 Rally Software Development Corp. All Rights Reserved.

require 'rallyeif-wrk'
require './testrail-api-master/ruby/testrail.rb'

#require 'debugger'
#debugger

RecoverableException   = RallyEIF::WRK::RecoverableException if not defined?(RecoverableException)
UnrecoverableException = RallyEIF::WRK::UnrecoverableException
RallyLogger            = RallyEIF::WRK::RallyLogger
XMLUtils               = RallyEIF::WRK::XMLUtils

#GetClearQuestAPIVersionMajor, GetClearQuestAPIVersionMinor

module RallyEIF
  module WRK
                          
    class TestRailConnection < Connection

      attr_reader :testrail, :artifact_class
      
      #
      # Global info that will be obtained from the TestRail system.
      #
      @testrail     = '' # The connecton packet used to make request.
      @tr_user_info = '' # TestRail information about user in config file.
      
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
#########
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
        
        @artifact_class = artifact_type
        #set_field_types(@artifact_class)

        return @testrail
      end
#########
      def create_internal(int_work_item)
        RallyLogger.debug(self,"Preparing to create one TestRail: '#{@artifact_class}'")
        begin
          #new_item = @artifact_class.new(int_work_item)
          #temp = new_item.save
          #new_item = @artifact_class.find(temp)  #otherwise we don't get the Name/ID
          case @artifact_class
          when :testcase
            # Create a TestRail TestCase
            tc_fields  = {
              'title'         => 'Time-' + Time.now.strftime("%Y-%m-%d_%H:%M:%S") + '-' + Time.now.usec.to_s,
              'type_id'       => 6,
              'priority_id'   => 5,
              'estimate'      => '3m14s',
              'milestone_id'  => 1,
              'refs'          => '',
            }
            new_item = @testrail.send_post('add_case/1', tc_fields)
            new_item.merge!({'TypeOfArtifact'=>:testcase})
          else
            raise UnrecoverableException.new("Unrecognize value for @artifact_class ('#{@artifact_class}')", self)
          end
        rescue RuntimeError => ex
          raise RecoverableException.copy(ex, self)
        end
        RallyLogger.debug(self,"Created #{@artifact_class} #{new_item['id']}")
        return new_item
      end
#########
      def disconnect()
        # TODO
        RallyLogger.info(self,"Would disconnect at this point if we needed to")
      end
#########
      def field_exists? (field_name)
        # Is this a valid field name?
        if !@lower_atts.member? field_name.to_s.downcase
            RallyLogger.error(self, "TestRail field '#{field_name.to_s}' is not a valid field name")
            return false
        end
        return true
      end
#########
      # find_by_external_id is forced from inheritance
      def find_by_external_id(external_id)
        #return {@external_id_field.to_s=>external_id}
        #return @artifact_class.find(external_id)
        begin
          query = "SELECT Id,Subject FROM #{@artifact_type} WHERE #{@external_id_field} = '#{external_id}'"
          RallyLogger.debug(self, " Using SOQL query: #{query}")
          artifact_array = find_by_query(query)
        rescue Exception => ex
          raise UnrecoverableException.new("Failed search using query: #{query}.  \n TestRail api returned:#{ex.message}", self)
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
#########
      def find_by_query(string)
        unpopulated_items = @testrail.query(string)
        populated_items = []
        unpopulated_items.each do |item|
          populated_items.push(@artifact_class.find(item['Id']))
        end
        return populated_items
      end
#########
      def find_new()
        RallyLogger.info(self, "Find New TestRail #{@artifact_type}s")
        artifact_array = []
        begin
          query = "SELECT Id FROM #{@artifact_type} #{get_SOQL_where_for_new()}"
          RallyLogger.debug(self, " Using SOQL query: #{query}")
          artifact_array = find_by_query(query)
        rescue Exception => ex
          raise UnrecoverableException.new("Failed search using query: #{query}.  \n TestRail api returned:#{ex.message}", self)
          raise UnrecoverableException.copy(ex,self)
        end
        
        RallyLogger.info(self, "Found #{artifact_array.length} new #{@artifact_type}s in #{name()}.")
        return artifact_array
      end
#########
      def find_updates(reference_time)
        RallyLogger.info(self, "Find Updated TestRail #{@artifact_type}s since '#{reference_time}' (class=#{reference_time.class})")
        artifact_array = []
        begin
          query = "SELECT Id,Subject FROM #{@artifact_type} #{get_SOQL_where_for_updates()}"
          RallyLogger.debug(self, " Using SOQL query: #{query}")
          artifact_array = find_by_query(query)
        rescue Exception => ex
          raise UnrecoverableException.new("Failed search using query: #{query}.  \n TestRail api returned:#{ex.message}", self)
          raise UnrecoverableException.copy(ex,self)
        end
        
        RallyLogger.info(self, "Found #{artifact_array.length} updated #{@artifact_type}s in #{name()}.")

        return artifact_array
      end
#########
      # This method will hide the actual call of how to get the id field's value
      def get_id_value(artifact)
        RallyLogger.debug(self,"#{artifact.attributes}")
        return artifact["Id"]
      end
######### 
      def get_object_link(artifact)
        # We want:  "<a href='https://<TestRail server>/<Artifact ID>'>link</a>"
        linktext = artifact[@id_field] || 'link'
        it = "<a href='https://#{@url}/#{artifact['Id']}'>#{linktext}</a>"
        return it
      end
#########
      def get_SOQL_where_for_new()
        query_string = "WHERE #{@external_id_field} = null"
        if !@soql_copy.nil? && !@soql_copy.empty?
          query_string = "#{query_string} AND (#{@soql_copy})"
        end
        query_string.gsub!(/\"/,"'")
        return query_string
      end
#########
      def get_SOQL_where_for_updates()
        query_string = "WHERE #{@external_id_field} != ''"
        if !@update_query.nil? && !@update_query.empty?
          query_string = "#{query_string} AND #{@update_query}"
        end
        query_string.gsub!(/\"/,"'")
        return query_string
      end
#########
      def pre_create(int_work_item)
        return int_work_item
      end
#########
      def set_field_types(artifact_class)
        @field_types    = {}
        @boolean_fields = []
        @lower_atts     = []
        artifact_class.attributes.each do |field|
          @field_types[field]=artifact_class.field_type(field)
          if @field_types[field] == "boolean"
            @boolean_fields.push(field)
          end
          @lower_atts.push field.to_s.downcase 
        end
        return @boolean_fields
      end
#########
      def update_internal(artifact, int_work_item)
        #artifact.update_attributes int_work_item
require 'debugger'
debugger
        case artifact['TypeOfArtifact']
        when :testcase
require 'debugger'
debugger
          updated_item = @testrail.send_post("update_case/#{artifact['id']}", int_work_item)
require 'debugger'
debugger
          updated_item.merge!({'TypeOfArtifact'=>:testcase})
        else
          raise UnrecoverableException.new("Unrecognize value for artifact: '#{artifact}'", self)
        end
        return artifact
      end
#########
      def update_external_id_fields(artifact, external_id, end_user_id, item_link)
        RallyLogger.debug(self, "Updating TestRail item <ExternalIDField> field (#{@external_id_field}) to '#{external_id}'")
require 'debugger'
debugger
        external_id_sysname = 'custom_' + @external_id_field.to_s.downcase
        fields = {external_id_sysname => external_id} # we should always have one

        # Rally gives us a full '<a href=' tag
        if !item_link.nil?
          url_only = item_link.gsub(/.* href=["'](.*?)['"].*$/, '\1')
          fields[@external_item_link_field] = url_only unless @external_item_link_field.nil?
        end
        RallyLogger.debug(self, "Updating TestRail item <CrosslinkUrlField> field (#{@external_item_link_field}) to '#{fields[@external_item_link_field]}'")
        
        fields[@external_end_user_id_field] = end_user_id unless @external_end_user_id_field.nil?
        RallyLogger.debug(self, "Updating TestRail item <ExternalEndUserIDField>> field (#{@external_end_user_id_field}) to '#{fields[@external_end_user_id_field]}'")
        
        update_internal(artifact, fields)
      end
#########
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
#########
    end
  end
end
