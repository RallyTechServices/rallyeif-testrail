#!/usr/bin/env ruby
# ============================================================================ #
# Script:
# Purpose:
# Usage:
# ============================================================================ #

$my_rally_base_url      = 'https://demo-test.rallydev.com/slm'
$my_rally_username      = 'paul@foo.com'
$my_rally_password      = 'MyPassword!'
$my_rally_workspace     = 'Integrations'
$my_rally_project       = 'MyProject'

@stop_after             = 100

$my_rally_custfield     = 'TestRailID'  # Rally custom field that contains TestRail ID.
$my_rally_custfield     = 'ExternalID'  # Rally custom field that contains TestRail ID.

require 'rally_api'


# ------------------------------------------------------------------------------
# Error exit codes.  Failed when...
#
OK_EXIT_STOPAFTER   = 0     # No error, just exit
ERR_EXIT_RALLYFIND  = -1    # ... querying Rally for TestCase.
ERR_EXIT_RALLY_UPD  = -2    # ... trying to update Rally TestCase.
ERR_EXIT_ARGS2MANY  = -3    # Too many command line args.
ERR_EXIT_ARGINVALID = -4    # Invalid command line arg.


# ------------------------------------------------------------------------------
# Validate command line argument.
#
def check_arg()
    if ARGV.length > 1
        print "ERROR: Too many command line args.\n"
        print "USAGE: #{$PROGRAM_NAME}  [--FixThemAll]\n"
        exit ERR_EXIT_ARGS2MANY
    end
    if ARGV.length == 1 && ARGV[0] != '--FixThemAll'
        print "ERROR: Invalid argument on command line: '#{ARGV[0]}'\n"
        print "USAGE: #{$PROGRAM_NAME}  [--FixThemAll]\n"
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
    $my_rally_headers.name    = 'fix-name-title-mismatch.rb'
    $my_rally_headers.vendor  = 'Technical-Services'
    $my_rally_headers.version = '1.235'

    config = {  :base_url   => $my_rally_base_url,
                :username   => $my_rally_username,
                :password   => $my_rally_password,
                :workspace  => $my_rally_workspace,
                :project    => $my_rally_project,
                :version    => $my_rally_version,
                :headers    => $my_rally_headers
    }

    @rally_con = RallyAPI::RallyRestJson.new(config)
    return @rally_con
end


# ------------------------------------------------------------------------------
# Fetch a Rally TestCase.
#
def get_all_testcases()
    print "\n--------------------------------------------------------\n"
    print "03) Find all pertinent Rally TestCases...\n"
    q                       = RallyAPI::RallyQuery.new()
    q.type                  = 'TestCase'
    q.fetch                 = "Name,ObjectID,FormattedID,#{$my_rally_custfield}"
    q.project_scope_up      = false
    q.project_scope_down    = true
    q.query_string          = "(#{$my_rally_custfield} != \"\")"
    begin
        all_testcases = @rally_con.find(q)
    rescue Exception => ex
        print "ERROR: During rally.find; arg1='#{q}'\n"
        print "       Message returned: #{ex.message}\n"
        exit ERR_EXIT_RALLYFIND
    end
    print "\tFound '#{all_testcases.length}' Rally TestCases matching query: #{q.query_string}\n"

    return all_testcases
end


# ------------------------------------------------------------------------------
# Main
#
check_arg()
get_my_vars()
connect_to_rally()
all_tc = get_all_testcases()

print "\n--------------------------------------------------------\n"
print "04) Clearing Rally TestCases with populated '#{$my_rally_custfield}' field:\n"

all_tc.each_with_index do |this_tc, ndx_tc|
    #print "FmtID='#{this_tc.FormattedID}'  OID='#{this_tc.ObjectID}'  #{$my_rally_custfield}='#{this_tc[$my_rally_custfield]}'\n"
    if this_tc[$my_rally_custfield] != ''
        print "\tTestcase='#{this_tc.FormattedID}';  clearing field '#{$my_rally_custfield}' of '#{this_tc[$my_rally_custfield]}'\n"
        if ARGV[0] != '--FixThemAll'
            print "\tnothing being modified...\n"
        else
            fields_to_update = {"c_#{$my_rally_custfield}" => ''}
            begin
                this_tc.update(fields_to_update)
            rescue Exception => ex
                print "ERROR: During tc.update; arg1='#{fields_to_update}'\n"
                print "       Message: #{ex.message}\n"
                exit ERR_EXIT_RALLY_UPD
            end
        end
        if ndx_tc+1 >= @stop_after
            print "\n\n\tNOTE: Script variable '@stop_after' is set to '#{@stop_after}'; exiting...\n"
            exit OK_EXIT_STOPAFTER
        end
    end
end


#the end#
