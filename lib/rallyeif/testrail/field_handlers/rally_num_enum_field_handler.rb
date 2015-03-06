# Copyright 2001-2015 Rally Software Development Corp. All Rights Reserved.

# Take care of mapping an enumerated type in one system to the other
# (handles cases where the value coming from the other system are actual numbers
#  instead of just string representations of numbers (1 instead of "1"))
#  <RallyNumEnumFieldHandler>
#    <FieldName>Severity</FieldName>
#    <Mappings>
#      <Field><Rally>Crash Data/Loss</Rally> <Other>1</Other></Field>
#      <Field><Rally>Major Problem</Rally>   <Other>2</Other></Field>
#      <Field><Rally>Minor Problem</Rally>   <Other>3</Other></Field>
#      <Field><Rally>Cosmetic</Rally>        <Other>4</Other></Field>
#    </Mappings>
#  </RallyNumEnumFieldHandler>

module RallyEIF
  module WRK
    module FieldHandlers

      class RallyNumEnumFieldHandler < RallyFieldHandler
        attr_reader :rally_enum_mappings, :other_enum_mappings

        def initialize(field_name = nil)
          super(field_name)
          @rally_enum_mappings = {}
          @other_enum_mappings = {}
        end

        #Transform value from intermediate work item to go "in" to Other system
        def transform_in(value)
          mapped_value = @other_enum_mappings[value]
          if mapped_value.nil? && value.is_a?(Numeric)
            mapped_value = @other_enum_mappings["#{value}"]
          end
          
          RallyLogger.warning(self, "For #{@field_name} field could not transform_in(#{value})") if mapped_value.nil?
          return mapped_value
        end

        #Transform value coming "out" of Other system into one for intermediate work item
        def transform_out(artifact)
          value = @connection.get_value(artifact, @field_name)
          mapped_value = @rally_enum_mappings[value]
          RallyLogger.warning(self, "For #{@field_name} field could not transform_out(#{value})") if mapped_value.nil?
          return mapped_value
        end

        #two hashes to store enum_mappings keyed on corresponding system
        #so that we can deal with the other system mapping multiple values to one Rally Value
        def read_config(fh_element)
          fh_element.elements.each do |element|
            if (element.name == "FieldName")
              @field_name = element.text.intern
            elsif (element.name == "Mappings")
              @rally_enum_mappings = XMLUtils.read_mapping(element)
              @other_enum_mappings = XMLUtils.read_mapping(element, false, true)
            else
              RallyLogger.warning(self, "Element #{element.text} not expected")
            end
          end
          if (@field_name == nil)
            RallyLogger.error(self, "FieldName must not be null")
          end
          if (@rally_enum_mappings == nil)
            RallyLogger.error(self, "Mappings must not be null")
          end
        end
      end

    end
  end
end
