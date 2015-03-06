#!/usr/bin/env ruby
# ------------------------------------------------------------------------------
# SCRIPT:
#       SetFields.rb
#
# PURPOSE:
#       Set fields to a given value.
#
$MU = <<end_of_usage
USAGE:  #{$PROGRAM_NAME}  Object  IDlist  SysField  NewValue

Where:
    Object   - Is the name of the TestRail object (TC=testcase)
    IDlist   - A comma-seperated list of object ID's to be modified
               (an element in the list can be a range like x..y)
    SysField - The TestRail 'system_name' of the field to be modified
    NewValue - Value to be put into 'SysField'

Example:
    ./SetFields.rb  TC  2..4,424..433  custom_rallyobjectid  ''
end_of_usage
$my_util_name   = 'SetFields.rb'
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
# Check that we have access to the required Ruby GEM(s).
#
failed_requires = 0
%w{debugger  ./lib/testrail-api-master/ruby/testrail.rb}.each do |this_Require|
  begin
    require this_Require
  rescue LoadError
    print "ERROR: This script requires Ruby GEM: '#{this_Require}'\n"
    ZZfailed_requires += 1
  end
end
if failed_requires > 0
    exit -1
end


# ------------------------------------------------------------------------------
# Load (and maybe override with) my personal/private variables from a file.
#
dir_name = File.dirname($PROGRAM_NAME)
my_vars = "#{dir_name}/MyVars.rb"
if FileTest.exist?( my_vars )
  print "Sourcing #{my_vars}...\n"
  require my_vars
else
  print "File #{my_vars} not found; skipping require...\n"
end


# ------------------------------------------------------------------------------
# Process args.
#
if ARGV[0] == "-h" || ARGV[0] == "--help" || ARGV[0] == nil
  print "#{$MU}"
  exit
end
a_obj   = ARGV[0]
a_id    = ARGV[1]
a_field = ARGV[2]
a_value = ARGV[3]

supported_objects = ['tc']
if supported_objects.include?(a_obj.downcase) == false
    print "ERROR: Object type '#{a_obj}' is not in the list of supported object types: #{supported_objects}\n"
    exit -1
end


# ------------------------------------------------------------------------------
# Get a TestRail connection.
#
def get_testrail_connection()
    @tr_con         = nil
    @tr_case_types  = nil
    @tr_case_fields = nil

    print "Connecting to TestRail system at:\n"
    print "\tURL  : #{$my_testrail_url}\n"
    print "\tUser : #{$my_testrail_user}\n"

    # ------------------------------------------------------------------
    # Set up a TestRail connection packet.
    #
    @tr_con          = TestRail::APIClient.new($my_testrail_url)
    @tr_con.user     = $my_testrail_user
    @tr_con.password = $my_testrail_password

    print "\nValidated by TestRail system:\n"
    print "\tUser : #{@tr_con.user}\n"
end


def get_case_fields()
    # ------------------------------------------------------------------
    # Get test case custom fields.
    #
    uri = 'get_case_fields'
    @tr_case_fields  = @tr_con.send_get(uri)
    cf_types = ['',             # 0
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
    fields = [  'estimate'		        ,
                'estimate_forecast'		,
                'id'		            ,
                'milestone_id'		    ,
                'priority_id'		    ,
                'refs'		            ,
                'section_id'		    ,
                'suite_id'		        ,
                'title'		            ,
                'type_id'		        ,
                'updated_by'		    ,
                'updated_on'		    ]
    @tr_case_fields.sort_by { |rec| rec['id']}.each do |this_CF|
        fields.push(this_CF['system_name'])
    end
    return fields
end


get_testrail_connection()

all_fields = get_case_fields()
if all_fields.include?(a_field) == false
    print "ERROR: Did not find a field with system_name '#{a_field}'\n"
    print "       Known fields: #{all_fields}\n"
    exit -1
end
print "\tField: #{a_field}\n"

# ------------------------------------------------------------------------------
# Step thru each element of the IDlist.
#
a_id.split(',').each  do |numset|
    # change single number to a range
    if numset.include? '..'
        inner = numset
    else
        inner = numset + '..' + numset
    end
    rng=inner.split('..').inject { |s,e| s.to_i..e.to_i }

    # loop thru the range
    rng.each do |objid|
        obj_before = @tr_con.send_get("get_case/#{objid}")
        new_field = {a_field => a_value}
        obj_after = @tr_con.send_post("update_case/#{objid}", new_field)
        print "\tFixed object id '#{objid}', field '#{a_field}', old '#{obj_before[a_field]}', new '#{obj_after[a_field]}'\n"
    end
end


# ------------------------------------------------------------------------------
# All done.
#
print "\n#{$my_util_name} utility complete\n"


#end#
