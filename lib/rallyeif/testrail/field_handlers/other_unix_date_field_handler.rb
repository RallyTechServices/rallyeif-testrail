# Copyright 2001-2015 Rally Software Development Corp. All Rights Reserved.

#
#   <OtherUnixDateFieldHandler>
#     <FieldName>created_on</FieldName>
#   </OtherUnixDateFieldHandler>

module RallyEIF
  module WRK
    module FieldHandlers
      
      class OtherUnixDateFieldHandler < RallyEIF::WRK::FieldHandlers::OtherFieldHandler
      
        def initialize(field_name = nil)
          super(field_name)
        end
        
        def transform_out(artifact)
          other_value = @connection.get_value(artifact,@field_name)
          if other_value.nil?
            return nil
          end
                    
          if other_value.is_a? Integer || other_value.to_i
            #return Time.at(other_value).to_datetime.strftime("%FT%TZ")
            return Time.at(other_value).utc.iso8601
          else
            return nil
          end
        end #end transform_out
      
        def transform_in(value)
          raise RecoverableException.new("Transforming in for Hash Fields is Not Implemented ", self)
        end
        
        def read_config(fh_element)
          fh_element.elements.each do |element|
            if ( element.name == "FieldName" )
              @field_name = get_element_text(element).intern
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
