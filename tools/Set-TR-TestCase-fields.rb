#!/usr/bin/env ruby
# ------------------------------------------------------------------------------
# SCRIPT:
#       Set-TR-TestCase-fields.rb
#
# PURPOSE:
#       Used to set the values in a given field of TestCases.
#
$MU = <<end_of_usage
USAGE:  #{$PROGRAM_NAME}  IDlist  SysField  NewValue

Where:
    IDlist   - A comma-seperated list of object ID's to be modified
               (an element in the list can be a range like x..y)
    SysField - The TestRail 'system_name' of the field to be modified
    NewValue - Value to be put into 'SysField'

Example:
    ./SetFields.rb  2..4,424..433  custom_rallyobjectid  ''
end_of_usage
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
# Check that we can load the required Ruby GEM(s).
#
def require_gems()
    print "--------------------------------------------------------\n"
    print "01) Loading the required Ruby GEMs\n"
    failed_requires = 0
    all_reqs = %w{./lib/testrail-api-master/ruby/testrail.rb}
    all_reqs.each do |this_Require|
      begin
        require this_Require
      rescue LoadError
        print "ERROR: This script requires Ruby GEM: '#{this_Require}'\n"
        failed_requires += 1
      end
    end
    if failed_requires > 0
        exit -1
    end
end


# ------------------------------------------------------------------------------
# Load (and maybe override with) my personal/private variables from a file.
#
def load_variables()
    print "--------------------------------------------------------\n"
    dir_name = File.dirname($PROGRAM_NAME)
    my_vars = "#{dir_name}/MyVars.rb"
    if FileTest.exist?( my_vars )
      print "02) Sourcing #{my_vars}\n"
      require my_vars
    else
      print "02) File #{my_vars} not found; skipping require\n"
    end
    $my_util_name   = 'Set-TR-TestCase-fields.rb'
end


# ------------------------------------------------------------------------------
# Get a TestRail connection.
#
def get_testrail_connection()
    @tr_con         = nil
    @tr_case_types  = nil
    @tr_case_fields = nil

    print "--------------------------------------------------------\n"
    print "03) Connecting to TestRail system at\n"
    print "\tURL  : #{$my_testrail_url}\n"
    print "\tUser : #{$my_testrail_user}\n"

    # ------------------------------------------------------------------
    # Set up a TestRail connection packet.
    #
    @tr_con          = TestRail::APIClient.new($my_testrail_url)
    @tr_con.user     = $my_testrail_user
    @tr_con.password = $my_testrail_password
end


# ------------------------------------------------------------------------------
# Get fields names on a TestCase.
#
def get_case_fields()
    print "--------------------------------------------------------\n"
    print "04) Get list of all TestCase field names\n"
    uri = 'get_case_fields'
    @tc_fields  = @tr_con.send_get(uri)
    # Known standard field types on Test Case
    @all_tc_fields = [  'estimate'		        ,
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
    # Add the custom field names to the list
    @tc_fields.sort_by { |rec| rec['id']}.each do |this_CF|
        @all_tc_fields.push(this_CF['system_name'])
    end

    return @all_tc_fields
end


# ------------------------------------------------------------------------------
# Process args.
#
def process_args()
    print "--------------------------------------------------------\n"
    print "05) Process the command-line arguments\n"
    if ARGV[0] == "-h" || ARGV[0] == "--help" || ARGV[0] == nil
      print "#{$MU}"
      exit
    end
    if ARGV.length != 3
        print "ERROR:  Wrong argument count\n"
        print "#{$MU}"
        exit -1
    end
    @a_id    = ARGV[0]  # Id(s) of TestCase(s)
    @a_field = ARGV[1]  # Field name to modify
    @a_value = ARGV[2]  # New value to put into field
    
    if @all_tc_fields.include?(@a_field) == false
        print "\tERROR: Did not find a Case field with a system_name of: '#{@a_field}'\n"
        print "\t       Known Case fields: #{@all_tc_fields}\n"
        exit -1
    end

    return
end


# ------------------------------------------------------------------------------
# Step thru each element of the IDlist.
#
def modify_testcases()
	print "--------------------------------------------------------\n"
	print "06) Will attempt to set TestCase field named '#{@a_field}' to '#{@a_value}'\n"
	@a_id.split(',').each  do |numset|
	    # change single number to a range
	    if numset.include? '..'
	        inner = numset
	    else
	        inner = numset + '..' + numset
	    end
	    rng=inner.split('..').inject { |s,e| s.to_i..e.to_i }
	
	    # loop thru the range
	    rng.each do |objid|
	        begin
	            uri = "get_case/#{objid}"
	            obj_before = @tr_con.send_get(uri)
	        rescue Exception => ex
	            print "\tERROR: Exception occurred on TestRail API 'send_get(#{uri})':\n"
	            print "\t       Message: #{ex.message}\n"
	            exit -1
	        end
	
	        new_field = {@a_field => @a_value}
	
	        begin
	            uri = "update_case/#{objid}"
	            obj_after = @tr_con.send_post(uri, new_field)
	        rescue Exception => ex
	            print "\tERROR: Exception occurred on TestRail API 'send_post(#{uri},#{new_field})':\n"
	            print "\t       Message: #{ex.message}\n"
	            exit -1
	        end
	        print "\tModified TestRail TestCase (id='#{objid}'), field '#{@a_field}', old='#{obj_before[@a_field]}', new='#{obj_after[@a_field]}'\n"
	    end
	end
end


# ------------------------------------------------------------------------------
# MAIN
#
require_gems()
load_variables()
get_testrail_connection()
all_tc_fields = get_case_fields()
process_args()
modify_testcases()


# ------------------------------------------------------------------------------
# All done.
#
print "--------------------------------------------------------\n"
print "07) Done: "
print "#{$my_util_name} utility complete\n"


#end#
