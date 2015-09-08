#!/usr/bin/env ruby

require '../lib/testrail-api-master/ruby/testrail.rb'

$my_testrail_url        = 'https://somewhere.testrail.com'
$my_testrail_user       = 'user@company.com'
$my_testrail_password   = 'MySecretPassword'


# ------------------------------------------------------------------------------
# Load (and maybe override with) my personal/private variables from a file.
#
my_vars = "./show-test-results.vars.rb"
if FileTest.exist?( my_vars )
    print "Sourcing #{my_vars}...\n"
    require my_vars
else
    print "File #{my_vars} not found; skipping require...\n"
end


# ------------------------------------------------------------------
# Set up a TestRail connection packet and connect.
#
print "\n01) Connecting to TestRail system at:\n"
print "\tURL  : #{$my_testrail_url}\n"
print "\tUser : #{$my_testrail_user}\n"

@tr_con          = TestRail::APIClient.new($my_testrail_url)
@tr_con.user     = $my_testrail_user
@tr_con.password = $my_testrail_password

print "\n02) Connected to the TestRail system:\n"
print "\tuser:#{@tr_con.user}\n"


# ------------------------------------------------------------------
# Get all results in a test.
#
def get_results(test_id)
    if !(/\A\d+\z/ === test_id.to_s)
        print "ERROR: get_results called with non-numeric :test_id = '#{test_id}'\n"
        exit -1
    end
    uri = "get_results/#{test_id}"
    begin
        @all_results = @tr_con.send_get(uri)
    rescue Exception => ex
        print "EXCEPTION occurred on TestRail API 'send_get(#{uri})':\n"
        print "\t#{ex.message}\n"
        print "\tFailed to retrieve list of results; exiting\n"
        exit -1
    end
    @all_results.each_with_index do |next_result,ndx_result|
        print ' '*14
        print "  result-%02d:"  %   [ndx_result+1]
        print "  id=%-3d"       %   [next_result['id']]
        print "  test_id=%d"    %   [next_result['test_id']]
        print "  comment=%s"    %   [next_result['comment']]
        print "  defects=%s"    %   [next_result['defects']]
        print "\n"
    end
    return
end


# ------------------------------------------------------------------
# Get all tests in a run.
#
def get_tests(run_id)
    if !(/\A\d+\z/ === run_id.to_s)
        print "ERROR: get_tests called with non-numeric :run_id = '#{run_id}'\n"
        exit -1
    end
    uri = "get_tests/#{run_id}"
    @all_tests = @tr_con.send_get(uri)
    #print "            tests found: '#{@all_tests.length}'\n" if @all_tests.length > 0
    @all_tests.each_with_index do |next_test,ndx_test|
        print ' '*10
        print "  test-%02d:"    %   [ndx_test+1]
        print "  id=%3d"        %   [next_test['id']]
        print "  run_id=%s"     %   [next_test['run_id']]
        print "  case_id=%s"    %   [next_test['case_id']]
        print "  title=%-20s"   %   [next_test['title']]
        print "\n"
        get_results(next_test['id'])
    end
    return
end


# ------------------------------------------------------------------
# Get all runs in a project.
#
def get_runs(proj_id)
    if !(/\A\d+\z/ === proj_id.to_s)
        print "ERROR: get_runs called with non-numeric :proj_id = '#{proj_id}'\n"
        exit -1
    end
    uri = "get_runs/#{proj_id}"
    @all_runs = @tr_con.send_get(uri)
    #print "        runs found: '#{@all_runs.length}'\n" if @all_runs.length > 0
    @all_runs.each_with_index do |next_run,ndx_run|
        print ' '*6
        print "  run-%02d:"     %   [ndx_run+1]
        print "  id=%d"         %   [next_run['id']]
        print "  name=%-20s"    %   [next_run['name']]
        print "\n"
        get_tests(next_run['id'])
    end
    return
end


# ------------------------------------------------------------------
# Get all projects.
#
uri = 'get_projects'
@all_projects = @tr_con.send_get(uri)
print "\n03) Total Projects found: '#{@all_projects.length}'\n"

@all_projects.each_with_index do |next_project,ndx_proj|
    print ' '*2
    print "  proj-%02d:"    %   [ndx_proj+1]
    print "  id=%-3d"       %   [next_project['id']]
    print "  name=%-20s"    %   [next_project['name']]
    print "\n"
    get_runs(next_project['id'])
end


#[the end]#
