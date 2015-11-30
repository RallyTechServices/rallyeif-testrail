#!/usr/bin/env ruby
# ============================================================================ #
# Script:
#       Delete-Rally-TestCases-wo-Owner.rb
# Purpose:
#       Used to delete Rally TestCases that do not have an Owner.
#       with them.
# Usage:
#       ruby ./Delete-Rally-TestCases-wo-Owner.rb [--DeleteThemAll]
#
#           Without the flag "--DeleteThemAll", this script will only display
#           those items that would otherwise be deleted.
# ============================================================================ #

$my_rally_base_url      = 'https://demo-test.rallydev.com/slm'
$my_rally_username      = 'paul@foo.com'
$my_rally_password      = 'MyPassword!'
$my_rally_workspace     = 'Integrations'
$my_rally_project       = 'MyProject'
$my_stop_after          = 1 # Delete this many, then stop (fail safe).


# ------------------------------------------------------------------------------
# Error exit codes.  Failed when...
#
OK_EXIT_STOPAFTER   = 0     # No error, just exit
ERR_EXIT_RALLYFIND  = -1    # ... querying Rally for TestCase.
ERR_EXIT_RALLY_DEL  = -2    # ... trying to delete Rally TestCase.
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
    $my_rally_headers.name    = 'Delete-Rally-TestCases-wo-Owner.rb'
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
# Fetch all Rally TestCases that have no Owner.
#
def get_all_testcases()
    print "\n--------------------------------------------------------\n"
    print "03) Find all Rally TestCases with no Owner...\n"
    q                       = RallyAPI::RallyQuery.new()
    q.type                  = 'TestCase'
    q.fetch                 = 'Name,ObjectID,FormattedID,Owner,CreationDate'
    q.workspace             = {'_ref' => @rally.rally_default_workspace._ref}
    q.project               = {'_ref' => @rally.rally_default_project._ref}
    q.project_scope_up      = false
    q.project_scope_down    = true
    q.query_string          = "(Owner = \"\")"
    begin
        all_testcases = @rally.find(q)
    rescue Exception => ex
        print "ERROR: During rally.find; arg1='#{q}'\n"
        print "       Message returned: #{ex.message}\n"
        exit ERR_EXIT_RALLYFIND
    end
    print "\tFound '#{all_testcases.length}' Rally TestCases matching query: #{q.query_string}\n"

    all_ownerless_testcases = []
    all_testcases.each_with_index do |this_tc, index_tc|
	    if this_tc.Owner.nil?
            all_ownerless_testcases.push(this_tc)
        end
    end

    return all_ownerless_testcases
end


# ------------------------------------------------------------------------------
# Main
#
check_arg()
get_my_vars()
connect_to_rally()
all_ownerless_testcases = get_all_testcases()

print "\n--------------------------------------------------------\n"
print "04) Removing Rally TestCases that have no Owner:\n"
if all_ownerless_testcases.length < 1
    print "\tNo candidates for deletion found\n"
else
	all_ownerless_testcases.each_with_index do |this_tc, ndx_tc|
	    if this_tc.Owner.nil?
	        print "\t#{ndx_tc+1} - Deleting TestCase='#{this_tc.FormattedID}'  ObjectID='#{this_tc.ObjectID}'  CreationDate='#{this_tc.CreationDate}'  Name='#{this_tc.Name}'\n"
	        if ARGV[0] != '--DeleteThemAll'
	            print "\t\tnothing being deleted (lack of #{$special_flag} flag)\n"
	        else
	            begin
	                this_tc.delete()
	            rescue Exception => ex
	                print "ERROR: During this_tc.delete;\n"
	                print "       Message: #{ex.message}\n"
	                exit ERR_EXIT_RALLY_DEL
	            end
	        end
	        if ndx_tc+1 >= $my_stop_after
	            print "\n\n\tNOTE: Script variable '$my_stop_after' is set to '#{$my_stop_after}'; exiting...\n"
	            exit OK_EXIT_STOPAFTER
	        end
	    end
	end
end

#the end#
