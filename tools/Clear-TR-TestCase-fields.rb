#!/usr/bin/env ruby
# ------------------------------------------------------------------------------
# SCRIPT:
#       Clear-TR-TestCase-fields.rb
#
# PURPOSE:
#       A script used to clear the values from custom fields on TestCase objects
#       in a desired TestRail Project.
#
# VERSION:
#       2.0
#
# ASSUMPTIONS:
#       1) All custom fields are of type 'String'.
#       2) A custom field named 'foo' can be specified on the command line as
#          either 'foo' or 'custom_foo'
#       3) The user of this script will modify the variable '@stop_after' for
#          their purposes.
#
$MU = <<end_of_usage
\n--------------------------------------------------------
USAGE:  #{$PROGRAM_NAME}  ProjectName FieldName1[,FieldName2,...]  [--really-do-it]

Where:
    ProjectName    - Is the name of the TestRail Project.
    FieldNameX     - A comma-eparated list of TestRail field names to be cleared.
    --really-do-it - A special flag: really modify the TestRail TestCases.

Example:
    ./Clear-TR-fields.rb  MyTestProject  RallyObjectID,RallyFormattedID
end_of_usage
$my_util_name   = 'Clear-TR-fields.rb'
# ------------------------------------------------------------------------------


$my_testrail_url        = 'https://mine.testrail.com'
$my_testrail_user       = 'mine@rallydev.com'
$my_testrail_password   = 'FooBar'

@stop_after             = 5 # Modify this many TestRail TestCases and then quit.


# ------------------------------------------------------------------------------
# Error exit codes.  Failed when...
#
OK_EXIT_NOERROR     =  0    # No error, just exit.
OK_EXIT_STOPAFTER   =  0    # No error, just stop after X objects are done.
ERR_EXIT_REQUIRES   = -1    # ... doing 'require' on needed GEMs.
ERR_EXIT_2PROJECTS  = -2    # ... found 2 projects with same name.
ERR_EXIT_NOPROJECTS = -3    # ... no projects were found in TestRail.
ERR_EXIT_PROJECTINV = -4    # ... project name was invalid.
ERR_EXIT_FIELDINV   = -5    # ... a field name was invalid.
ERR_EXIT_SUITES     = -6    # ... getting Suites form desired project.
ERR_EXIT_CUSTOMTC   = -7    # ... getting custom fields on TestCases.
ERR_EXIT_PROJGET    = -8    # ... getting information about all TestRail Projects.
ERR_EXIT_CONNECT    = -9    # ... connecting to TestRails.


# ------------------------------------------------------------------------------
# Check that we have access to the required Ruby GEM(s).
#
def load_requires()
    print "\n--------------------------------------------------------\n"
    print "01) Loading required GEMs...\n"
    failed_requires = 0
    %w{./lib/testrail-api-master/ruby/testrail.rb}.each do |this_Require|
        begin
            require this_Require
        rescue LoadError
            print "ERROR: This script requires Ruby GEM: '#{this_Require}'\n"
            failed_requires += 1
        end
    end
    if failed_requires > 0
        exit ERR_EXIT_REQUIRES
    end
end


# ------------------------------------------------------------------------------
# Override some variables if the myvars file is present.
#
def get_my_vars()
    print "\n--------------------------------------------------------\n"
    dir_name = File.dirname($PROGRAM_NAME)
    my_vars = "#{dir_name}/MyVars.rb"
    if FileTest.exist?( my_vars )
        print "02) Sourcing #{my_vars}...\n"
        require my_vars
    else
        print "02) File #{my_vars} not found; skipping require...\n"
    end
end


# ------------------------------------------------------------------------------
# Process args.
#
def get_commandline_args()
    print "\n--------------------------------------------------------\n"
    print "03) Extracting command line arguments...\n"

    @special_flag = '--really-do-it'
    all_args = ARGV
    if all_args.include?(@special_flag)
        @modify_the_data = true
        all_args = all_args - [@special_flag]
    else
        @modify_the_data = false
        print "\tPreview mode; nothing will be modified...\n"
    end

    if all_args[0] == "-h" || all_args[0] == "--help" || all_args[0] == nil || all_args.length != 2
        print "#{$MU}"
        exit OK_EXIT_NOERROR
    end
    @desired_project = ARGV[0]
    @desired_fields  = ARGV[1]
end


# ------------------------------------------------------------------------------
# Connect to Testrail.
#
def connect_to_testrail()
    print "\n--------------------------------------------------------\n"
    print "04) Connecting to TestRail system at:\n"
    print "\tURL     : #{$my_testrail_url}\n"
    print "\tUser    : #{$my_testrail_user}\n"
    print "\tPassword: ********\n"
    begin
        @tr_con = TestRail::APIClient.new($my_testrail_url)
    rescue Exception => ex
        print "\tEXCEPTION occurred when connecting to TestRail API:\n"
        print "\t#{ex.message}\n"
        print "\tFailed to connect with TestRail.\n"
        exit ERR_EXIT_CONNECT
    end
    @tr_con.user     = $my_testrail_user
    @tr_con.password = $my_testrail_password
    return @tr_con
end


# ------------------------------------------------------------------------------
# Get a list of all custom field names for TestRail TestCase objects.
#
def get_case_fields()
    print "\n--------------------------------------------------------\n"
    print "05) Valid custom field names for a TestRail TestCase object:\n"
    @tc_fields = []

    # Get all the custom field names...
    begin
        uri = 'get_case_fields'
        @tr_case_custfields  = @tr_con.send_get(uri)
    rescue Exception => ex
        print "\tEXCEPTION occurred on TestRail API 'send_get(#{uri})':\n"
        print "\t#{ex.message}\n"
        print "\tFailed to get information about TestRail custom fields on TestCases.\n"
        exit ERR_EXIT_CUSTOMTC
    end

    @tr_case_custfields.sort_by { |rec| rec['id']}.each do |this_CF|
        @tc_fields.push(this_CF['system_name'])
    end
    print "\t#{@tc_fields}\n"
    return @tc_fields
end


# ------------------------------------------------------------------------------
# Find requested project.
#
def find_requested_project()
    print "\n--------------------------------------------------------\n"
    print "06) Find desired project: '#{@desired_project}'\n"

    # Get a list of all projects...
    begin
        uri = 'get_projects'
        all_projects = @tr_con.send_get(uri)
    rescue Exception => ex
        print "\tEXCEPTION occurred on TestRail API 'send_get(#{uri})':\n"
        print "\t#{ex.message}\n"
        print "\tFailed to get information about all TestRail Projects.\n"
        exit ERR_EXIT_PROJGET
    end
    if all_projects.length > 1
        print "\tFound a total of '#{all_projects.length}' projects.\n"
    else
        print "\tERROR: No projects found... exiting...\n"
        exit ERR_EXIT_NOPROJECTS
    end

    # Found our desired project in the list...
    @target_proj = nil
    all_projects.each do |this_PROJECT|
        if this_PROJECT['name'] == @desired_project
            if @target_proj.nil?
                @target_proj = this_PROJECT
                break
            else
                print "\tERROR: Found more than one project named: '#{@desired_project}'\n"
                exit ERR_EXIT_2PROJECTS
            end
        end
    end
    if @target_proj.nil?
        print "\tERROR: Can't find desired project '#{@desired_project}'\n"
        exit ERR_EXIT_PROJECTINV
    end
    print "\tUsing desired project '#{@target_proj['name']}' (id=#{@target_proj['id']}).\n"

    # Get all suites in our desired project...
    if @target_proj['suite_mode'] != 3
        # This seems to work
        @target_suites = [ {'id' => @target_proj['id']} ]
    else
        begin
            uri = "get_suites/#{@target_proj['id']}"
            @target_suites = @tr_con.send_get(uri)
        rescue Exception => ex
            print "\tEXCEPTION occurred on TestRail API 'send_get(#{uri})':\n"
            print "\t#{ex.message}\n"
            print "\tFailed to get information about all TestRail suites in desired project.\n"
            exit ERR_EXIT_SUITES
        end
        print "\n\tFound '#{@target_suites.length}' suites in the desired project: ["
        suiteids = Array.new # Build an array of suite ID's for display...
        @target_suites.each_with_index do |this_suite, ndx_suite|
            suiteids.push(this_suite['id'])
            sep = ndx_suite+1 == @target_suites.length ? "]\n" : ",  "
            print "#{this_suite['id']}='#{this_suite['name']}'#{sep}"
        end
    end
    return @target_proj, @target_suites
end


# ------------------------------------------------------------------------------
# Be sure command-line field names are valid.
#
def check_requested_fields()
    print "\n--------------------------------------------------------\n"
    print "07) Validate desired fields...\n"
    found_a_bad_field = false
    @fields_2b_modified = []
    @desired_fields.split(',').each_with_index do |this_field, ndx_field|
        this_field = this_field.downcase
        if @tc_fields.include?(this_field) == true
            print "\tField OK: #{this_field}\n"
            @fields_2b_modified.push(this_field)
        else
            if @tc_fields.include?('custom_' + this_field) == true
                print "\tField OK: custom_#{this_field}\n"
                @fields_2b_modified.push('custom_' + this_field)
            else
                print "\tERROR: Did not find a field with system_name '#{this_field}'\n"
                found_a_bad_field = true
            end
        end
    end
    if found_a_bad_field == true
        print "\tERROR: Invalid field name(s) found (above); exiting'\n"
        exit ERR_EXIT_FIELDINV
    end
    return
end


# ------------------------------------------------------------------------------
# Get all TestRail TestCases in our desired project.
#
def get_all_testcases()
    print "\n--------------------------------------------------------\n"
    print "08) Get all TestRail TestCases in desired project...\n"

    # Step thru all Suites, getting all TestCase in each Suite...
    @all_testcases = Array.new
    @target_suites.each_with_index do |this_suite, ndx_suite|
        begin
            uri = "get_cases/#{@target_proj['id']}&suite_id=#{this_suite['id']}"
            testcases = @tr_con.send_get(uri)
        rescue Exception => ex
            print "\tEXCEPTION occurred on TestRail API 'send_get(#{uri})':\n"
            print "\t#{ex.message}\n"
            print "\tFailed to get TestCases from Suite '#{this_suite['id']}'.\n"
            exit ERR_EXIT_SUITES
        end
        print "\tFound '#{testcases.length}' testcases in Suite '#{this_suite['id']}'.\n"
        @all_testcases.concat(testcases)
    end
    print "\tFound a total of '#{@all_testcases.length}' testcases in Suite.\n"

    # Determine which need to be updated (i.e. new does not equal current value)...
    @testcases_2b_updated = {}
    update_yes = 0
    update_no  = 0
    @all_testcases.each_with_index do |this_tc, ndx_tc|
        jps_old_data = {}
        jps_new_data = {}
        @fields_2b_modified.each_with_index do |this_field, ndx_field|
            if this_tc[this_field] != nil
                if this_tc[this_field] != '' # not sure this one was necessary?
                    jps_old_data[this_field] = this_tc[this_field]
                    jps_new_data[this_field] = ''
                end
            end
        end
        if !jps_new_data.empty?
            update_yes += 1
            @testcases_2b_updated[this_tc['id']] = [jps_old_data, jps_new_data]
        else
            update_no += 1
        end
    end
    print "\tFound '#{update_yes}' that need updating, and '#{update_no}' that do not.\n"
    return @testcases_2b_updated
end


# ------------------------------------------------------------------------------
# Step thru all TestCases and modify them.
#
def update_all_testcases()
    print "\n--------------------------------------------------------\n"
    print "09) Update all TestRail TestCases in desired project...\n"
    print "\tWill stop after '#{@stop_after}' TestCases are done (value of @stop_after variable).\n"
    if @modify_the_data == true
        print "\tOBJECTS WILL NOW BE MODIFIED...\n"
    else
        print "\tObjects will not be modified (lack of '#{@special_flag}' flag).\n"
    end

    total_done = 0
    @testcases_2b_updated.each_with_index do |this_tc, ndx_tc|
        if @modify_the_data == true
            updated_tc = @tr_con.send_post("update_case/#{this_tc[0]}", this_tc[1][1])
        else
            puts "Test mode: NOTHING DONE."
        end
        print "\tFixed object id '#{this_tc[0]}'   old='#{this_tc[1][0]}'  new='#{this_tc[1][1]}'\n"
        total_done += 1
        if total_done >= @stop_after
            print "\n\n\tNOTE: Script variable '@stop_after' is set to '#{@stop_after}'; exiting...\n"
            exit OK_EXIT_STOPAFTER
        end
    end
    return
end


# ------------------------------------------------------------------------------
# MAIN:
#
load_requires()
get_my_vars()
get_commandline_args()
connect_to_testrail()
get_case_fields()
find_requested_project()
check_requested_fields()
get_all_testcases()
update_all_testcases()


# ------------------------------------------------------------------------------
# All done.
#
print "\n#{$my_util_name} utility complete\n"


#end#
