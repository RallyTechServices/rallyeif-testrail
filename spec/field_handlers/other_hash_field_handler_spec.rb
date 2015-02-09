# Copyright 2001-2015 Rally Software Development Corp. All Rights Reserved.
require File.dirname(__FILE__) + '/../spec_helpers/spec_helper'
require File.dirname(__FILE__) + '/../spec_helpers/testrail_spec_helper'

include TestRailSpecHelper
include YetiTestUtils

describe 'Hash Field Handler Tests' do

  mapped_field_name = "_testcase"
  referenced_field_name = "id"
  
  fieldhandler_config = "
  <OtherHashFieldHandler>
    <FieldName>#{mapped_field_name}</FieldName>
    <ReferencedFieldLookupID>#{referenced_field_name}</ReferencedFieldLookupID>  
  </OtherHashFieldHandler>"

  before(:each) do
    @connection = testrail_connect(TestRailSpecHelper::TESTRAIL_STATIC_CONFIG)
    @unique_number = Time.now.strftime("%Y%m%d%H%M%S") + '-' + Time.now.usec.to_s
  end

  after(:all) do
    @connection.disconnect() if !@connection.nil?
  end

  it "should return nil if there is no value to transform_out" do
    item = {'name' => 'test title'}

    root = YetiTestUtils::load_xml(fieldhandler_config).root
    fh = RallyEIF::WRK::FieldHandlers::OtherHashFieldHandler.new
    fh.connection = @connection
    fh.read_config(root)
    expect( fh.transform_out(item) ).to be_nil
  end
  
  it "should return nil if there the transform_out value is an empty string" do
    item = {'name' => 'test title', mapped_field_name => '' }

    root = YetiTestUtils::load_xml(fieldhandler_config).root
    fh = RallyEIF::WRK::FieldHandlers::OtherHashFieldHandler.new
    fh.connection = @connection
    fh.read_config(root)
    expect( fh.transform_out(item) ).to be_nil
  end
    
  it "should return nil if there the transform_out value is an empty array" do
    item = {'name' => 'test title', mapped_field_name => [] }

    root = YetiTestUtils::load_xml(fieldhandler_config).root
    fh = RallyEIF::WRK::FieldHandlers::OtherHashFieldHandler.new
    fh.connection = @connection
    fh.read_config(root)
    expect( fh.transform_out(item) ).to be_nil
  end
  
  it "should throw exception on transform_in" do
    root = YetiTestUtils::load_xml(fieldhandler_config).root
    fh = RallyEIF::WRK::FieldHandlers::OtherHashFieldHandler.new
    fh.read_config(root)
    expect { fh.transform_in("") }.to raise_error(/Not Implemented/)
  end

  it "should correctly transform_out if there is a value to transform" do
    field_value = {
        "dc:title" => "Wilma",
        referenced_field_name => "Fred"
    }
      
    item = {'dc:title' => 'test title', mapped_field_name => field_value }

    root = YetiTestUtils::load_xml(fieldhandler_config).root
    fh = RallyEIF::WRK::FieldHandlers::OtherHashFieldHandler.new
    fh.connection = @connection
    fh.read_config(root)
    expect( fh.transform_out(item) ).to eq("Fred")
  end

  it "should transform_out a nil if cannot find item with the reference field" do
    field_value = {
        "rdf:resource"=>"abc defg"
    }
      
    item = {'dc:title' => 'test title', mapped_field_name => field_value }

    root = YetiTestUtils::load_xml(fieldhandler_config).root
    fh = RallyEIF::WRK::FieldHandlers::OtherHashFieldHandler.new
    fh.connection = @connection
    fh.read_config(root)
    expect( fh.transform_out(item) ).to be_nil
  end
  
end
