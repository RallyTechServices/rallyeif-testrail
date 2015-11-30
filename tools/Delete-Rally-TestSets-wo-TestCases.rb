#!/usr/bin/env ruby
# ============================================================================ #
# Script:
#       Delete-Rally-TestSets-wo-TestCases.rb
# Purpose:
#       Used to delete all TestSets that have no (zero) TestCases associated
#       with them.
# Usage:
#       ruby Delete-Rally-TestSets-wo-TestCases.rb [--DeleteThemAll]
#
#           Without the flag "--DeleteThemAll", this script will only display
#           those items that would otherwise be deleted.
# ============================================================================ #

$my_rally_base_url      = 'https://demo-test.rallydev.com/slm'
$my_rally_username      = 'paul@foo.com'
$my_rally_password      = 'MyPassword!'
$my_rally_workspace     = 'Integrations'
$my_rally_project       = 'MyProject'

@stop_after             = 1 # Delete this many, then stop (fail safe).


# ------------------------------------------------------------------------------
# Error exit codes.  Failed when...
#
OK_EXIT_STOPAFTER   = 0     # No error, just exit
ERR_EXIT_RALLYFIND  = -1    # ... querying Rally for TestSet.
ERR_EXIT_RALLY_UPD  = -2    # ... trying to update Rally TestSet.
ERR_EXIT_ARGS2MANY  = -3    # Too many command line args.
ERR_EXIT_ARGINVALID = -4    # Invalid command line arg.

require 'rally_api'
$special_flag = '--DeleteThemAll'


# ------------------------------------------------------------------------------
# Validate command line argument.
#
def check_arg()
    if ARGV.length > 1
        print "ERROR: Too many command line args.\n"
        print "USAGE: #{$PROGRAM_NAME}  [#{$special_flag}]\n"
        exit ERR_EXIT_ARGS2MANY
    end
    if ARGV.length == 1 && ARGV[0] != "#{$special_flag}"
        print "ERROR: Invalid argument on command line: '#{ARGV[0]}'\n"
        print "USAGE: #{$PROGRAM_NAME}  [#{$special_flag}]\n"
        exit ERR_EXIT_ARGINVALID
    end
end


# ------------------------------------------------------------------------------
# Override some variables if the myvars file is present.
#
def get_my_vars()
    print "--------------------------------------------------------\n"
    my_vars = './MyVars.rb'
    if FileTest.exist?( my_vars )
        print "01) Sourcing #{my_vars}...\n"
        require my_vars
    else
        print "01) File #{my_vars} not found; skipping require...\n"
    end
end


# ------------------------------------------------------------------------------
# Connect to Rally.
#
def connect_to_rally()
    # removing trailing '/' if present and add '/slm' if needed
    $my_rally_base_url = $my_rally_base_url.chomp('/')
    $my_rally_base_url << '/slm' if !$my_rally_base_url.end_with?('/slm')

    $my_rally_version       = 'v2.0'

    print "\n--------------------------------------------------------\n"
    print "02) Connecting to Rally at:\n"
    print "\tBaseURL  : <#{$my_rally_base_url}>\n"
    print "\tUserName : <#{$my_rally_username}>\n"
    print "\tWorkspace: <#{$my_rally_workspace}>\n"
    print "\tProject  : <#{$my_rally_project}>\n"
    print "\tVersion  : <#{$my_rally_version}>\n"

    $my_rally_headers = RallyAPI::CustomHttpHeader.new()
    $my_rally_headers.name    = 'Delete-Rally-TestSets-wo-TestCases.rb'
    $my_rally_headers.vendor  = 'Technical-Services'
    $my_rally_headers.version = '1.2345'

    config = {  :base_url   => $my_rally_base_url,
                :username   => $my_rally_username,
                :password   => $my_rally_password,
                :workspace  => $my_rally_workspace,
                :project    => $my_rally_project,
                :version    => $my_rally_version,
                :headers    => $my_rally_headers
    }

    @rally = RallyAPI::RallyRestJson.new(config)
    return @rally
end


# ------------------------------------------------------------------------------
# Fetch all Rally TestSets that have no TestCases associated with them.
#
def get_all_testsets()
    print "\n--------------------------------------------------------\n"
    print "03) Find all pertinent Rally TestSets...\n"
    q                       = RallyAPI::RallyQuery.new()
    q.type                  = 'TestSet'
    q.fetch                 = "Name,ObjectID,FormattedID,TestCaseCount"
    q.workspace             = {'_ref' => @rally.rally_default_workspace._ref}
    q.project               = {'_ref' => @rally.rally_default_project._ref}
    q.project_scope_up      = false
    q.project_scope_down    = true
    q.query_string          = "(ObjectID > 0)"
    begin
        all_testsets = @rally.find(q)
    rescue Exception => ex
        print "ERROR: During rally.find; arg1='#{q}'\n"
        print "       Message returned: #{ex.message}\n"
        exit ERR_EXIT_RALLYFIND
    end
    print "\tFound '#{all_testsets.length}' Rally TestSets matching query: #{q.query_string}\n"

    all_childless_testsets = []
    all_testsets.each_with_index do |this_ts, index_ts|
	    if this_ts.TestCaseCount == 0
            all_childless_testsets.push(this_ts)
        end
    end

    return all_childless_testsets
end


# ------------------------------------------------------------------------------
# Main
#
check_arg()
get_my_vars()
connect_to_rally()
all_childless_testsets = get_all_testsets()

print "\n--------------------------------------------------------\n"
print "04) Removing Rally TestSets that have no TestCases:\n"
if all_childless_testsets.length < 1
    print "\tNo candidates for deletion found\n"
else
	all_childless_testsets.each_with_index do |this_ts, ndx_ts|
	    if this_ts.TestCaseCount == 0
	        print "\tDeleting TestSet='#{this_ts.FormattedID}'  Name='#{this_ts.Name}'  ObjectID='#{this_ts.ObjectID}'  TestCaseCount'#{this_ts.TestCaseCount}'\n"
	        if ARGV[0] != '--DeleteThemAll'
	            print "\t\tnothing being deleted (lack of #{$special_flag} flag)\n"
	        else
	            begin
	                this_ts.delete()
	            rescue Exception => ex
	                print "ERROR: During this_ts.delete;\n"
	                print "       Message: #{ex.message}\n"
	                exit ERR_EXIT_RALLY_UPD
	            end
	        end
	        if ndx_ts+1 >= @stop_after
	            print "\n\n\tNOTE: Script variable '@stop_after' is set to '#{@stop_after}'; exiting...\n"
	            exit OK_EXIT_STOPAFTER
	        end
	    end
	end
end

#the end#
