#!/usr/bin/env ruby

require './lib/testrail-api-master/ruby/testrail.rb'

$my_testrail_url        = 'https://tsrally.testrail.com'
$my_testrail_user       = 'user@company.com'
$my_testrail_password   = 'MySecretPassword'


# ------------------------------------------------------------------------------
# Load (and maybe override with) my personal/private variables from a file.
#
my_vars = "./show-test-case.vars.rb"
if FileTest.exist?( my_vars )
    print "Sourcing #{my_vars}...\n"
    require my_vars
else
    print "File #{my_vars} not found; skipping require...\n"
end


# ------------------------------------------------------------------------------
# Connect to TestRail.
#
@tr_con          = TestRail::APIClient.new($my_testrail_url)
@tr_con.user     = $my_testrail_user
@tr_con.password = $my_testrail_password
print "\n----------------------------------------------\n"
print "01) Will Connect to TestRail system with:\n"
print "\t     URL : #{$my_testrail_url}\n"
print "\t    User : #{$my_testrail_user}\n"
print "\tPassword : #{$my_testrail_password.gsub(/./,'*')}\n"


# ------------------------------------------------------------------
# Find all projects.
#
print "\n----------------------------------------------\n"
print "02) Retrieving all projects...'\n"

uri = 'get_projects'
begin
    all_projects = @tr_con.send_get(uri)
rescue Exception => ex
    print "EXCEPTION occurred on TestRail API 'send_get(#{uri})':\n"
    print "\t#{ex.message}\n"
    print "\tFailed to retrieve list of projects; exiting\n"
    exit -1
end


# ------------------------------------------------------------------
# Display all projects.
#
print "\n----------------------------------------------\n"
print "03) Found #{all_projects.length} projects:'\n"
all_projects.each_with_index do |proj,ndx|
    # Each project in the array:
    # {"id"=>1, "name"=>"Test-Proj-sm3", "announcement"=>"This is a project 'Test-Proj-01'.",
    #  "show_announcement"=>true, "is_completed"=>false, "completed_on"=>nil, "suite_mode"=>3,
    #  "url"=>"https://tsrally.testrail.com/index.php?/projects/overview/1"}
    print "\t%2d -"                 %   [ndx+1]
    print "  id=%-4d"               %   [proj['id']]
    print "  name=%-18s"            %   [proj['name']]
    print "  suite_mode=%1d"        %   [proj['suite_mode']]
    print "  is_completed=%s"       %   [proj['is_completed']]
    print "  show_announcement=%-5s"%   [proj['show_announcement']]
    print "  completed_on=%s"       %   [proj['completed_on']]
    print "\n"
end


# ------------------------------------------------------------------
# All done.
#
print "\n----------------------------------------------\n"
print "Done.\n"


#[the end]#
