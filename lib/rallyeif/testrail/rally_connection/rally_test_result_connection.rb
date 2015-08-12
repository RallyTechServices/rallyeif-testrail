# Copyright 2001-2014 Rally Software Development Corp. All Rights Reserved.

# Rally TestCaseResult does not support an ExternalIDField so we extend RallyConnection to overwrite validate and set_external_id_fields methods

module RallyEIF
  module WRK

    class RallyTestResultConnection < RallyConnection

      def initialize(config=nil)
        super(config)
      end

      def read_config(config)
        super(config)
      end
      
      def validate()
        check = true
        rally_tc_field_handler = false

        if not valid_artifact?(@artifact_type)
          RallyLogger.error(self, "#{@artifact_type} is not a valid artifact type for the #{self.class.to_s}")
          check = false
        end

        #Check id fields for [RallyConnection,OtherConnection] x [id_field,external_id_field] fields
        if not field_exists?(id_field())
          RallyLogger.error(self, "<IDField> #{@id_field} not found")
          check = false
        end

        #Check field handlers
        rally_tc_field_handler = @field_handlers.select {|fh| fh.field_name.to_s == 'TestCase'}
        if rally_tc_field_handler.nil? || rally_tc_field_handler.empty?
           rally_tc_field_handler = false
        end
        @field_handlers.each { |field_handler|
          next if field_handler.field_name.to_s == 'TestCase'
          if not field_exists?(field_handler.field_name)
            RallyLogger.error(self, "Field Handler field_name #{field_handler.field_name} not found")
            check = false
          end
        }
        if not rally_tc_field_handler
          RallyLogger.error(self, "Rally Reference Field Handler for TestCase not found")
          check = false
        end

        #Check field defaults
        @field_defaults.each { |attr, value|
          if field_exists?(attr) == false
            RallyLogger.error(self, "Field Defaults field_name #{attr} not found")
            check = false
          end
        }

        #Check whether all of the @copy_selectors are valid
        if @copy_selectors.length > 0
          @copy_selectors.each do |cs|
            if not field_exists?(cs.field)
              RallyLogger.error(self, "CopySelector field_name #{cs.field} not found")
              check = false
            end
          end
        end

        return check
      end
      
      def find_result_with_build(build)
        RallyLogger.debug(self,"Build: #{build}")
        begin
          query_result = @rally.find do |q|
            q.type      = 'testcaseresult'
            q.workspace = @workspace
            q.fetch     = true
            q.query_string = "(Build = #{build})"
          end
        rescue Exception => ex
          raise UnrecoverableException.copy(ex, self)
        end        
        return query_result.first
      end
      
      def result_with_build_exists?(build,test_date)
        RallyLogger.debug(self,"Build: #{build}, Test Date: #{test_date}")
        begin
          query_result = @rally.find do |q|
            q.type      = 'testcaseresult'
            q.workspace = @workspace
            q.fetch     = true
            q.query_string = "((Build = #{build}) AND (Date = #{test_date}))"
          end
        rescue Exception => ex
          raise UnrecoverableException.copy(ex, self)
        end        
        return query_result.length > 0
      end
      
      def create_internal(int_work_item)
        build = int_work_item[:Build]
        test_date = int_work_item[:Date]
          
          
        if result_with_build_exists?(build,test_date)
          RallyLogger.info(self,"Skipping result #{int_work_item[:Build]} because it already exists")
          artifact = nil
        else
          begin
            artifact = @rally.create(@artifact_type, int_work_item)
          rescue Exception => ex
            raise RecoverableException.copy(ex, self)
          end
          RallyLogger.info(self, "  Created #{@artifact_type}; ObjectID='#{artifact["ObjectID"]}'")
        end
        return artifact
      end
      
      def set_external_id_fields(int_work_item, id_value, end_user_id_value=nil, item_link=nil)
        return int_work_item
      end

      def find_new()
        raise UnrecoverableException.new("COPY_RALLY_TO_OTHER not supported for #{@artifact_type}", self)
      end

      def find_updates(start_time)
        raise UnrecoverableException.new("UPDATE_RALLY_TO_OTHER not supported for #{@artifact_type}", self)
      end

      private
      def update_internal(artifact, int_work_item)
        raise UnrecoverableException.new("UPDATE_OTHER_TO_RALLY not supported for #{@artifact_type}", self)
      end

    end

  end
end
