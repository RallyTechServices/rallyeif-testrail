# Copyright 2001-2015 Rally Software Development Corp. All Rights Reserved.

#   When a field is passed as a hash, we will want to pull out a single field item
#   Imagine we have a hash in a field called _testcase = { 'id' => "1", 'name' => "fred" }
#
#   We can get "1" by using this config:
#   <OtherHashFieldHandler>
#     <FieldName>_testcase</FieldName>
#     <ReferencedFieldLookupID>id</ReferencedFieldLookupID>  <!-- the field inside the hash -->
#   </OtherHashFieldHandler>

module RallyEIF
  module WRK
    module FieldHandlers
      
    
      class OtherHashFieldHandler < RallyEIF::WRK::FieldHandlers::OtherFieldHandler
      
        def initialize(field_name = nil)
          super(field_name)
        end
        
        def transform_out(artifact)
         
          other_value = @connection.get_value(artifact,@field_name)
          if other_value.nil? || other_value.empty?
            return nil
          end
                    
          if other_value[@referenced_field_lookup_id] 
              return other_value[@referenced_field_lookup_id]
          else
            return nil
          end
        end
      
        def transform_in(value)
          raise RecoverableException.new("Transforming in for Hash Fields is Not Implemented ", self)
        end
        
        def read_config(fh_element)
          @referenced_field_lookup_id = "Name"  # use "Name" as the default field

          fh_element.elements.each do |element|
            if ( element.name == "FieldName" )
              @field_name = get_element_text(element).intern
            elsif ( element.name == "ReferencedFieldLookupID")
              @referenced_field_lookup_id = get_element_text(element)
            else
              problem = "Element #{element.name} not expected in OtherHashFieldHandler config"
              raise UnrecoverableException.new(problem, self)
            end
          end

        end #end read_config
         
      end
    end
  end
end
