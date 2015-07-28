#!/usr/bin/env ruby
#require 'pry';binding.pry

require '../lib/testrail-api-master/ruby/testrail.rb'

$my_testrail_url        = 'https://tsrally.testrail.com'
$my_testrail_user       = 'user@company.com'
$my_testrail_password   = 'MySecretPassword'

# ------------------------------------------------------------------------------
# Load (and maybe override with) my personal/private variables from a file.
#
my_vars = "./x.vars.rb"
if FileTest.exist?( my_vars )
    print "Sourcing #{my_vars}...\n"
    require my_vars
else
    print "File #{my_vars} not found; skipping require...\n"
end


def get_testrail_connection()
    @tr_con         = nil
    @tr_case_types  = nil
    @tr_case_fields = nil

    print "\n01) Connecting to TestRail system at:\n"
    print "\tURL  : '#{$my_testrail_url}'\n"
    print "\tUser : '#{$my_testrail_user}'\n"

    # ------------------------------------------------------------------
    # Set up a TestRail connection packet.
    #
    @tr_con          = TestRail::APIClient.new($my_testrail_url)
    @tr_con.user     = $my_testrail_user
    @tr_con.password = $my_testrail_password

    print "\n02) Connected to the TestRail system:\n"
    print "\tUser : '#{@tr_con.user}'\n"
end


# ------------------------------------------------------------------------------
# Get a list of all the projects.
#
def get_projects()
    uri = 'get_projects'
    @all_PROJECTs = @tr_con.send_get(uri)
    print "\n03) Total Projects found: '#{@all_PROJECTs.length}'\n"
    if @all_PROJECTs.length > 0
        @all_PROJECTs.each do |item|
            print "\tid:'%d'"           % [item['id']]
            print "  name:'%s'"         % [item['name']]
            print "  suite_mode:'%s'"   % [item['suite_mode']]
           #print "  url:'%s'"          % [item['url']]
            print "\n"
        end
    end
    return @all_PROJECTs
end
            

# ------------------------------------------------------------------------------
# Create a new TestRail project (it can not already exist).
#
def create_project(new_proj_name)
    @all_PROJECTs.each do |item|
        if item['name'] == new_proj_name
            print "\n"
            print "ERROR: Project '#{new_proj_name}' already exists (id='#{item['id']}').\n"
            print "       This utility is meant to create a new project.\n"
            print "       now exiting...\n"
            exit -1
        end
    end

    print "\n04) Creating new project: '#{new_proj_name}'\n"
    uri    = 'add_project'
    fields = {  'name'                => new_proj_name,
                'announcement'        => "JPKole's new project anouncement.",
                'show_announcement'   => true,
                'suite_mode'          => 3}
    @new_project = @tr_con.send_post(uri, fields)
    print "\tid:'#{@new_project['id']}'  suite_mode:'#{@new_project['suite_mode']}'  announcement:'#{@new_project['announcement']}'\n"
end


# ------------------------------------------------------------------------------
# Create a new TestRail project (it can not already exist).
#
def create_suites(suite_count)
    print "\n05) Creating '#{suite_count} suites in new project: '#{@new_project['name']}'\n"
    (1..suite_count).each do |next_suite|
        uri    = "add_suite/#{@new_project['id']}"
        fields = {  'name'          => "Suite '#{next_suite}' of '#{suite_count}'",
                    'description'   => "One of JPKole's test suites."
                 }
        @new_suite = @tr_con.send_post(uri, fields)
        print "\tid:'#{@new_suite['id']}'\n"
    end
end


##########---MAIN---##########


get_testrail_connection()
get_projects()
create_project("test-001")
create_suites(5)


#[the end]#
