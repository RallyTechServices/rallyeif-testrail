# Copyright 2001-2014 Rally Software Development Corp. All Rights Reserved.

require 'rallyeif-wrk'

RecoverableException   = RallyEIF::WRK::RecoverableException if not defined?(RecoverableException)
UnrecoverableException = RallyEIF::WRK::UnrecoverableException
RallyLogger            = RallyEIF::WRK::RallyLogger
XMLUtils               = RallyEIF::WRK::XMLUtils

#GetClearQuestAPIVersionMajor, GetClearQuestAPIVersionMinor

module RallyEIF
  module WRK
                              
    class TestRailConnection < Connection
      
      attr_reader :salesforce, :artifact_class, :soql_copy, :boolean_fields
      
      def initialize(config=nil)
        super()
        read_config(config) if !config.nil?
      end
      
      def read_config(config)
        super(config)
        @url = XMLUtils.get_element_value(config, self.conn_class_name.to_s, "Url")
        @client_id = XMLUtils.get_element_value(config, self.conn_class_name.to_s, "ConsumerKey")
        @client_secret = XMLUtils.get_element_value(config, self.conn_class_name.to_s, "ConsumerSecret")
        @soql_copy = XMLUtils.get_element_value(config, self.conn_class_name.to_s, "SOQLCopySelector", false)
        if !@soql_copy.nil?
          @soql_copy = get_where_from_soql(@soql_copy)
        end
      end
      
      def name()
        return "SalesForce"
      end
      
      def version()
        return RallyEIF::SalesForce::Version
      end

      def self.version_message()
        version_info = "#{RallyEIF::SalesForce::Version}-#{RallyEIF::SalesForce::Version.detail}"
        return "SalesForceConnection version #{version_info}"
      end
      
      def get_backend_version()
        return "%s %s" % [name, version]
      end
      
      def field_exists? (field_name)
        # Is this a valid field name?

        if !@lower_atts.member? field_name.to_s.downcase
            RallyLogger.error(self, "Salesforce field '#{field_name.to_s}' is not a valid field name")
            return false
        end
        return true
      end
      
      def disconnect()
        # TODO
        RallyLogger.info(self,"Would disconnect at this point if we needed to")
      end
      
      def connect()
        
        RallyLogger.debug(self, "********************************************************")
        RallyLogger.debug(self, "Connecting to SalesForce:")
        RallyLogger.debug(self, "  Url               : #{@url}")
        RallyLogger.debug(self, "  Username          : #{@user}")
        RallyLogger.debug(self, "  Connector Name    : #{name}")
        RallyLogger.debug(self, "  Connector Version : #{version}")
        RallyLogger.debug(self, "  Artifact Type     : #{artifact_type}")
        RallyLogger.debug(self, "  Consumer Key      : #{@client_id.gsub(/^(....).*(....)$/,'\1....<77 chars hidden>....\2')}")
        RallyLogger.debug(self, "  Consumer Secret   : #{@client_secret.gsub(/^(....).*(....)$/,'\1....<11 chars hidden>....\2')}")
        RallyLogger.debug(self, "*******************************************************")   
        @salesforce = Databasedotcom::Client.new :client_id => @client_id, :client_secret => @client_secret, :host => @url
        
        begin
          @salesforce.authenticate :username => @user, :password => @password
          RallyLogger.debug(self, "After authentication, about to materialize")
        rescue Databasedotcom::SalesForceError => ex
          raise UnrecoverableException.new("Cannot authenticate with username '#{@user}'.  \n SalesForce api returned:#{ex.message}", self)
        end
        
        begin
          @artifact_class = @salesforce.materialize(@artifact_type)
          RallyLogger.debug(self, "Materialize complete -- Fields: #{@artifact_class.attributes().join(',')}")
        rescue Databasedotcom::SalesForceError => ex
          raise UnrecoverableException.new("Could not find <ArtifactType> '#{@artifact_type}'.\n SalesForce api returned: #{ex.message}", self)
        end
        
        set_field_types(@artifact_class)

        return @salesforce
      end
  
      def validate
        status_of_all_fields = true  # Assume all fields passed
        
        if !field_exists?(@external_id_field)
          status_of_all_fields = false
          RallyLogger.error(self, "Salesforce <ExternalIDField> '#{@external_id_field}' does not exist")
        end

        if @id_field
          if !field_exists?(@id_field)
            status_of_all_fields = false
            RallyLogger.error(self, "Salesforce <IDField> '#{@id_field}' does not exist")
          end
        end

        if @external_end_user_id_field
          if !field_exists?(@external_end_user_id_field)
            status_of_all_fields = false
            RallyLogger.error(self, "Salesforce <ExternalEndUserIDField> '#{@external_end_user_id_field}' does not exist")
          end
        end
        
        return status_of_all_fields
      end
      
      def set_field_types(artifact_class)
        @field_types = {}
        @boolean_fields = []
        @lower_atts = []
        artifact_class.attributes.each do |field| 
          @field_types[field]=artifact_class.field_type(field)
          if @field_types[field] == "boolean"
            @boolean_fields.push(field)
          end
          @lower_atts.push field.to_s.downcase 
        end
        return @boolean_fields
      end
      
      # find_by_external_id is forced from inheritance
      def find_by_external_id(external_id)
        #return {@external_id_field.to_s=>external_id}
        #return @artifact_class.find(external_id)
        begin
          query = "SELECT Id,Subject FROM #{@artifact_type} WHERE #{@external_id_field} = '#{external_id}'"
          RallyLogger.debug(self, " Using SOQL query: #{query}")
          artifact_array = find_by_query(query)
        rescue Exception => ex
          raise UnrecoverableException.new("Failed search using query: #{query}.  \n SalesForce api returned:#{ex.message}", self)
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
      
      def find_by_query(string)
        unpopulated_items = @salesforce.query(string)
        populated_items = []
        unpopulated_items.each do |item|
          populated_items.push(@artifact_class.find(item['Id']))
        end
        return populated_items
      end
      
      def get_SOQL_where_for_new()
        query_string = "WHERE #{@external_id_field} = null"
        if !@soql_copy.nil? && !@soql_copy.empty?
          query_string = "#{query_string} AND (#{@soql_copy})"
        end
        query_string.gsub!(/\"/,"'")
        return query_string
      end
      
      def get_SOQL_where_for_updates()
        query_string = "WHERE #{@external_id_field} != ''"
        if !@update_query.nil? && !@update_query.empty?
          query_string = "#{query_string} AND #{@update_query}"
        end
        query_string.gsub!(/\"/,"'")
        return query_string
      end
      
      def find_new()
        RallyLogger.info(self, "Find New SalesForce #{@artifact_type}s")
        artifact_array = []
        begin
          query = "SELECT Id FROM #{@artifact_type} #{get_SOQL_where_for_new()}"
          RallyLogger.debug(self, " Using SOQL query: #{query}")
          artifact_array = find_by_query(query)
        rescue Exception => ex
          raise UnrecoverableException.new("Failed search using query: #{query}.  \n SalesForce api returned:#{ex.message}", self)
          raise UnrecoverableException.copy(ex,self)
        end
        
        RallyLogger.info(self, "Found #{artifact_array.length} new #{@artifact_type}s in #{name()}.")
        return artifact_array
      end
      
      def find_updates(reference_time)
        RallyLogger.info(self, "Find Updated SalesForce #{@artifact_type}s since '#{reference_time}' (class=#{reference_time.class})")
        artifact_array = []
        begin
          query = "SELECT Id,Subject FROM #{@artifact_type} #{get_SOQL_where_for_updates()}"
          RallyLogger.debug(self, " Using SOQL query: #{query}")
          artifact_array = find_by_query(query)
        rescue Exception => ex
          raise UnrecoverableException.new("Failed search using query: #{query}.  \n SalesForce api returned:#{ex.message}", self)
          raise UnrecoverableException.copy(ex,self)
        end
        
        RallyLogger.info(self, "Found #{artifact_array.length} updated #{@artifact_type}s in #{name()}.")

        return artifact_array
      end
      
      def get_object_link(artifact)
        # We want:  "<a href='https://<SalesForce server>/<Artifact ID>'>link</a>"
        linktext = artifact[@id_field] || 'link'
        it = "<a href='https://#{@url}/#{artifact['Id']}'>#{linktext}</a>"
        return it
      end
    
      def pre_create(int_work_item)
        return int_work_item
      end
    
      def create_internal(int_work_item)
        RallyLogger.debug(self,"Preparing to create one #{@artifact_class}")
        begin
          new_item = @artifact_class.new(int_work_item)
          temp = new_item.save
          new_item = @artifact_class.find(temp)  #otherwise we don't get the Name/ID
        rescue RuntimeError => ex
          raise RecoverableException.copy(ex, self)
        end
        RallyLogger.debug(self,"Created #{@artifact_class} #{new_item['Id']}")
        return new_item
      end
      
      # This method will hide the actual call of how to get the id field's value
      def get_id_value(artifact)
        RallyLogger.debug(self,"#{artifact.attributes}")
        return artifact["Id"]
      end
    
      def update_internal(artifact, int_work_item)
        artifact.update_attributes int_work_item
        return artifact
      end
      
      def update_external_id_fields(artifact, external_id, end_user_id, item_link)

        RallyLogger.debug(self, "Updating SF item <ExternalIDField> field (#{@external_id_field}) to '#{external_id}'")
        fields = {@external_id_field => external_id} # we should always have one

        # Rally gives us a full '<a href=' tag
        if !item_link.nil?
          url_only = item_link.gsub(/.* href=["'](.*?)['"].*$/, '\1')
          fields[@external_item_link_field] = url_only unless @external_item_link_field.nil?
        end
        RallyLogger.debug(self, "Updating SF item <CrosslinkUrlField> field (#{@external_item_link_field}) to '#{fields[@external_item_link_field]}'")
        
        fields[@external_end_user_id_field] = end_user_id unless @external_end_user_id_field.nil?
        RallyLogger.debug(self, "Updating SF item <ExternalEndUserIDField>> field (#{@external_end_user_id_field}) to '#{fields[@external_end_user_id_field]}'")
        
        update_internal(artifact, fields)
      end
      
      # The following 'soql_copy' method should transpose the query as follows:
      #     Transform these strings                                  Into these strings
      #     --------------------------------------------             ------------------
      #     "Name like SF%"                                          "Name like SF%"
      #     "Name like WHERE %"                                      "Name like SF%"
      #     "SELECT Id FROM Case WHERE Name like SF%"                "Name like SF%"
      #                         "where Name like SF%"                "Name like SF%"
      #     "select Id FROM Case where Name like SF%"                "Name like SF%"
      #     "select Id FROM Case where Name like WHERE%"             "Name like WHERE%"
      #     "where Description like WHERE% and Subject like SELECT%" "Description like WHERE% and Subject like SELECT%"
      #
      #     "[Select <field>(s) from <table>] where <field> <condition> <value> [ {and|or} <field> like <value> ...]
      def get_where_from_soql(soql)
        # Steps: - strip leading and traling space
        #        - remove "^Select <> From <> "
        #        - remove "^Where "
        new_soql = soql.strip.gsub(/^Select\s+\S+\s+From\s+\S+\s+/i, '').gsub(/^Where\s+/i, '')
        return new_soql
      end

    end
  end
end
