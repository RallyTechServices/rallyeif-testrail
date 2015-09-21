#!/usr/bin/env ruby

require '../lib/testrail-api-master/ruby/testrail.rb'

$my_testrail_url        = 'https://tsrally.testrail.com'
$my_testrail_user       = 'user@company.com'
$my_testrail_password   = 'MySecretPassword'


# ------------------------------------------------------------------------------
# Load (and maybe override with) my personal/private variables from a file.
#
my_vars = "./MyVars.rb"
if FileTest.exist?( my_vars )
    print "01) Sourcing #{my_vars}...\n"
    require my_vars
else
    print "01) File #{my_vars} not found; skipping require...\n"
end


# ------------------------------------------------------------------
# Set up a TestRail connection packet and connect.
#
print "\n02) Connecting to TestRail system at:\n"
print "\tURL  : #{$my_testrail_url}\n"
print "\tUser : #{$my_testrail_user}\n"

@tr_con          = TestRail::APIClient.new($my_testrail_url)
@tr_con.user     = $my_testrail_user
@tr_con.password = $my_testrail_password

print "\n03) Connected to the TestRail system:\n"
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
# Get all runs in a project that are not in a plan.
#
def get_runs_not_in_plan(proj_id)
    if !(/\A\d+\z/ === proj_id.to_s)
        print "ERROR: get_runs_not_in_plan called with non-numeric :proj_id = '#{proj_id}'\n"
        exit -1
    end
    uri = "get_runs/#{proj_id}"
    @all_runs = @tr_con.send_get(uri)
    print "        runs not in a plan (#{@all_runs.length}):\n"
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
# Get all runs in a project that are in plans.
#
def get_runs_in_plan(proj_id)
    if !(/\A\d+\z/ === proj_id.to_s)
        print "ERROR: get_runs_in_plan called with non-numeric :proj_id = '#{proj_id}'\n"
        exit -1
    end
    uri = "get_plans/#{proj_id}"
    @all_plans = @tr_con.send_get(uri)
    print "        plans found (#{@all_plans.length}):\n"
    @all_plans.each_with_index do |next_plan,ndx_plan|
        uri = "get_plan/#{next_plan['id']}"
        plan = @tr_con.send_get(uri)
        print ' '*8 + "plan#{ndx_plan+1}:  id='#{plan['id']}'  name='#{plan['name']}'  is_completed='#{plan['is_completed']}'  #entries=#{plan['entries'].length}\n"
        plan['entries'].each_with_index do |next_ent,ndx_ent|
          print ' '*10 + "entries:  name='#{next_ent['name']}'  #runs=#{next_ent['runs'].length}\n"
          next_ent['runs'].each_with_index do |next_run,ndx_run|
            uri = "get_tests/#{next_run['id']}"
            tests = @tr_con.send_get(uri)
            print ' '*12 + "run:  id='#{next_run['id']}'  name='#{next_run['name']}  #tests=#{tests.length}'\n"
            tests.each_with_index do |next_test,ndx_test|
              uri = "get_results/#{next_test['id']}"
              results = @tr_con.send_get(uri)
              print ' '*14 + "test#{ndx_test+1}:  id='#{next_test['id']}'  title='#{next_test['title']}'  case_id='#{next_test['case_id']}'  #results='#{results.length}'\n"
              uri = "get_statuses"
#require 'byebug';byebug
              statuses = %w[UnKnown Passed Blocked Untested Retest Failed custom_status1]
              results.each_with_index do |next_result,ndx_result|
                strstat=statuses[next_result['status_id']]
                print ' '*16 + "result:  id='#{next_result['id']}'  status_id='#{next_result['status_id']}(#{strstat})'\n"
              end
            end
          end
        end
    end
    return
end


# ------------------------------------------------------------------
# Get all projects.
#
uri = 'get_projects'
@all_projects = @tr_con.send_get(uri)
print "\n04) Total Projects found: '#{@all_projects.length}'\n"

@all_projects.each_with_index do |next_project,ndx_proj|
    print ' '*2
    print "  proj-%02d:"    %   [ndx_proj+1]
    print "  id=%-3d"       %   [next_project['id']]
    print "  name=%-20s"    %   [next_project['name']]
    print "\n"
    if next_project['id'] == 26
        get_runs_not_in_plan(next_project['id'])
        get_runs_in_plan(next_project['id'])
    else
        print ' '*6 + "skipping details for project of no interest...\n"
    end
end


#[the end]#
