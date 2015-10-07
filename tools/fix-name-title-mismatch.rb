#!/usr/bin/env ruby
# ============================================================================ #
# Script:
#       fix-name-title-mismatch.rb
# Purpose:
#       A Ruby script used for finding all TestRail TestCases which are linked
#       to a Rally TestCase.  If the "Title" field on the TestRail TestCase does
#       not match the "Name" field on the linked Rally TestCase, then the Rally
#       TestCase "Name" field is modified to match (assuming the special flag
#       is given on the command line).
# Usage:
#       fix-name-title-mismatch.rb  [--FixThemAll]
#
#       Where the argument "--FixThemAll" is used to actually modify the "Name"
#       field on the Rally TestCases to match the corresponding TestRail
#       TestCase "Title".
# ============================================================================ #

$my_rally_base_url      = 'https://demo-test.rallydev.com/slm'
$my_rally_username      = 'paul@foo.com'
$my_rally_password      = 'MyPassword!'
$my_rally_workspace     = 'Integrations'
$my_rally_project       = 'MyProject'
$my_rally_version       = 'v2.0'

$my_testrail_url        = 'https://mine.testrail.com'
$my_testrail_user       = 'mine@rallydev.com'
$my_testrail_password   = 'FooBar'
$my_testrail_project    = 'BarFoo'

require 'rally_api'


# ------------------------------------------------------------------------------
# Error exit codes.  Failed when...
#
ERR_EXIT_GETPROJS   = -1    # ... getting information about all TestRail projects.
ERR_EXIT_NOPROJS    = -2    # ... trying to find projects in TestRail.
ERR_EXIT_PROJNF     = -3    # ... trying to find desired TestRail project.
ERR_EXIT_SUITES     = -4    # ... getting all Suite information.
ERR_EXIT_TESTCASES  = -5    # ... getting all TestCase information.
ERR_EXIT_RALLYFIND  = -6    # ... querying Rally for TestCase.
ERR_EXIT_RALLY_UPD  = -7    # ... trying to update Rally TestCase.
ERR_EXIT_ARGS2MANY  = -8    # Too many command line args.
ERR_EXIT_ARGINVALID = -9    # Invalid command line arg.


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
# Connect to Testrail.
#
def connect_to_testrail()

    require '../lib/testrail-api-master/ruby/testrail.rb'

    print "\n--------------------------------------------------------\n"
    print "02) Connecting to TestRail system at:\n"
    print "\tURL     : #{$my_testrail_url}\n"
    print "\tUser    : #{$my_testrail_user}\n"
    print "\tPassword: ********\n"
    print "\tProject : #{$my_testrail_project}\n"
    @tr_con          = TestRail::APIClient.new($my_testrail_url)
    @tr_con.user     = $my_testrail_user
    @tr_con.password = $my_testrail_password
    return @tr_con
end


# ------------------------------------------------------------------------------
# Connect to Rally.
#
def connect_to_rally()
    print "\n--------------------------------------------------------\n"
    print "03) Connecting to Rally at:\n"
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
# Get information about the desired project and all its suites.
#
def get_project_info()
    print "\n--------------------------------------------------------\n"
    print "04) Searching for project: '#{$my_testrail_project}'...\n"
    my_proj_info = nil

    # First, get all projects...
    uri = 'get_projects'
    begin
        all_PROJECTs = @tr_con.send_get(uri)
    rescue Exception => ex
        print "\tEXCEPTION occurred on TestRail API 'send_get(#{uri})':\n"
        print "\t#{ex.message}\n"
        print "\tFailed to get information about all TestRail projects'\n"
        exit ERR_EXIT_GETPROJS
    end

    # Try to find our desired project from the list of projects...
    if all_PROJECTs.length > 0
        all_PROJECTs.each do |item|
            if item['name'] == $my_testrail_project
                @tr_proj_info = item
                break
            end
        end
    else
        print "ERROR: No projects found in TestRail.'\n"
        exit ERR_EXIT_NOPROJS
    end
    if @tr_proj_info == nil
        print "ERROR: Could not find project named: '#{$my_testrail_project}'\n"
        exit ERR_EXIT_PROJNF
    end
    p = @tr_proj_info
    print "\tfound project:\n"
    print "\t           id = #{p['id']}\n"
    print "\t         name = #{p['name']}\n"
    print "\t   suite_mode = #{p['suite_mode']}\n"
    print "\t is_completed = #{p['is_completed']}\n"
    print "\t          url = #{p['url']}\n"
    if p['announcement'].nil?
        str = 'nil'
    else
        str = p['announcement'].gsub(/\n/,"\n\t\t\t")
    end
    print "\t announcement = #{str}\n"

    # Get all suites in our project...
    @tr_proj_id = @tr_proj_info['id']
    uri = "get_suites/#{@tr_proj_id}"
    begin
        @tr_suites = @tr_con.send_get(uri)
    rescue Exception => ex
        print "\tEXCEPTION occurred on TestRail API 'send_get(#{uri})':\n"
        print "\t#{ex.message}\n"
        print "\tFailed to get information about all TestRail suites in project.\n"
        exit ERR_EXIT_SUITES
    end
    suiteids = Array.new # Build an array of suite ID's for display...
    @tr_suites.each_with_index do |this_suite, index_suite|
        suiteids.push(this_suite['id'])
    end
    print "\n\tFound '#{@tr_suites.length}' suites in the project: '#{suiteids}'\n"

    return @tr_proj_info, @tr_suites
end


# ------------------------------------------------------------------------------
# Get all testcase in all the suites; makes hash of ObjectID => Title.
#
def get_all_testcases()
    print "\n--------------------------------------------------------\n"
    print "05) Getting all TestRail testcases in project '#{$my_testrail_project}'...\n"

    # Get all TestCases in each suite...
    tot_tc = 0
    @tr_testcases_per_suite = Array.new # each element is all testcases in a suite
    @tr_suites.each_with_index do |this_suite,index_suite|
        uri = "get_cases/#{@tr_proj_info['id']}&suite_id=#{this_suite['id']}"
        begin
            all_cases = @tr_con.send_get(uri)
        rescue Exception => ex
            print "\tEXCEPTION occurred on TestRail API 'send_get(#{uri})':\n"
            print "\t#{ex.message}\n"
            print "\tFailed to get TestRail testcases for suite '#{this_suite['id']}'\n"
            exit ERR_EXIT_TESTCASES
        end
        print "\tFound '#{all_cases.length}' testcases in suite '#{this_suite['id']}'\n"
        @tr_testcases_per_suite.push(all_cases)
        tot_tc += all_cases.length
    end
    print "\tTotal: '#{tot_tc}' testcases found.\n"

    # Step through all suites...
    tots=0
    @tc_titles = Hash.new # Has of Rally-ObjectID >> [Rally-FormattedID, TestRail-ID, TestRail-Title]
    @tr_testcases_per_suite.each_with_index do |this_tcset, index_tcset|
        # Step through all TestCases in this suite...
        this_tcset.each_with_index do |this_case, index_case|
            # Save only TestCases which have a populated custom field 'RallyObjectID'...
            if !this_case['custom_rallyobjectid'].nil?
                @tc_titles[this_case['custom_rallyobjectid']] = [this_case['custom_rallyformattedid'], this_case['id'], this_case['title']]
                tots += 1
            end
        end
    end
    print "\tFound '#{tots}' testcases linked to Rally\n"
end


# ------------------------------------------------------------------------------
# Fetch a Rally TestCase.
#
def get_rally_testcase(tc_oid)
    q                       = RallyAPI::RallyQuery.new()
    q.type                  = 'TestCase'
    q.fetch                 = 'Name'
    q.page_size             = 1
    q.limit                 = 1
    q.project_scope_up      = false
    q.project_scope_down    = true
    q.query_string          = "(ObjectID = \"#{tc_oid}\")"

    begin
        results = @rally_con.find(q)
    rescue Exception => ex
        print "ERROR: During rally.find; arg1='#{q}'\n"
        print "       Message returned: #{ex.message}\n"
        exit ERR_EXIT_RALLYFIND
    end

    return results.first
end


# ------------------------------------------------------------------------------
# (No longer used) Read a Rally TestCase.
#
def get_rally_testcase_ORIG(tc_oid)
    begin
        tc = @rally_con.read('testcase', tc_oid)
    rescue Exception => ex
        print "ERROR: During rally.read; arg1='testcase',  arg2='#{tc_oid}'\n"
        print "       Message returned: #{ex.message}\n"
        exit ERR_EXIT_RALLYFIND
    end
    return tc
end


# ------------------------------------------------------------------------------
# update the Rally testcase with new Name
#
def update_rally_testcase(tc,title)
    print "\tUpdated from='#{tc.Name}'\n"
    print "\t          to='#{title}'\n"
    fields_to_update = {'Name' => title}
    begin
        tc.update(fields_to_update)
    rescue Exception => ex
        print "ERROR: During tc.update; arg1='#{fields_to_update}'\n"
        print "       Message: #{ex.message}\n"
        exit ERR_EXIT_RALLY_UPD
    end
end


#
# Main
#
check_arg()
get_my_vars()
connect_to_testrail()
connect_to_rally()
get_project_info()
get_all_testcases()

print "\n--------------------------------------------------------\n"
print "06) Search all linked testcases for mismatching TestRail-Title/Rally-Name fields...\n"
print "\tTestRailid-RallyFormattedID:\n\t\t"
mismatching = Hash.new
items_on_line = 0
@tc_titles.each_with_index do |all4, ndx|
    # Separate hash of:  OID --> Array[FmtID, ID, Title]
    rally_oid = all4[0]    # Rally-ObjectID
    rally_fid = all4[1][0] # Rally-FormattedID
    tr_id     = all4[1][1] # TestRail-ID
    tr_title  = all4[1][2] # TestRail-Title
    print " C#{tr_id}-#{rally_fid}"
    items_on_line = items_on_line + 1
    tc = get_rally_testcase(rally_oid)
    if tc.Name != tr_title
        #print "TestRail Title / Rally Name mismatch: id='#{tr_id}' FormattedID='#{rally_fid}' ObjectID='{rally_oid}'\n"
        print "<--MisMatch!\n"
        mismatching[rally_oid] = tr_title
        if ARGV[0] != '--FixThemAll'
            print "\t\t(not fixing the above item)\n"
        else
            update_rally_testcase(tc,tr_title)
        end
        print "\tTestRailid-RallyFormattedID (continuing):\n\t\t"
        items_on_line = 0
    end
    if items_on_line != 0 && items_on_line%5 == 0 # print 5 items per line
        print "\n\t\t"
        items_on_line = 0
    end
end

print "\nFound '#{mismatching.length}' mismatching T-Title/R-Name.\n"


#the end#
