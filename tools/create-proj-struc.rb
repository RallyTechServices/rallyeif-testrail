#!/usr/bin/env ruby
#require 'pry';binding.pry


$my_testrail_url        = 'https://tsrally.testrail.com'
$my_testrail_user       = 'user@company.com'
$my_testrail_password   = 'MySecretPassword'


# ------------------------------------------------------------------------------
# Check that we have access to the required Ruby GEM(s).
#
%w{benchmark ../lib/testrail-api-master/ruby/testrail.rb}.each do |this_Require|
    begin
        require this_Require
    rescue LoadError
        print "ERROR: Required Ruby GEM '#{this_Require}' not found; exiting.\n"
        exit (-1)
    end
end


# ------------------------------------------------------------------------------
# Load (and maybe override with) my personal/private variables from a file.
#
my_vars = "./create-proj-struc.vars.rb"
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
    return
end


# ------------------------------------------------------------------------------
# Create a new TestRail project (it can not already exist).
#
def create_new_project(new_proj_name)
    uri = 'get_projects'
    @all_projs = @tr_con.send_get(uri)
    if @all_projs.length > 0
        # Does the project already exist?
        @all_projs.each do |item|
            if item['name'] == new_proj_name
                print "\n"
                print "ERROR: Project '#{new_proj_name}' already exists (id='#{item['id']}').\n"
                print "       This utility is meant to create a new project.\n"
                print "       now exiting...\n"
                exit -1
            end
        end
    end

    # Create the new project.
    print "\n04) Creating new project: '#{new_proj_name}'\n"
    uri    = 'add_project'
    fields = {  'name'                => new_proj_name,
                'announcement'        => "JPKole's new project anouncement.",
                'show_announcement'   => true,
                'suite_mode'          => 3}
    @new_project = @tr_con.send_post(uri, fields)
    print "\tid:'#{@new_project['id']}'  suite_mode:'#{@new_project['suite_mode']}'  announcement:'#{@new_project['announcement']}'\n"
    return
end


# ------------------------------------------------------------------------------
# Create a number of new TestRail suites.
#
def create_suites(suite_count)
    print "\n05) Creating '#{suite_count} suites in new project: '#{@new_project['name']}'\n"
    @all_suites = Array.new
    (1..suite_count).each do |next_suite|
        uri    = "add_suite/#{@new_project['id']}"
        fields = {  'name'          => "Suite '#{next_suite}' of '#{suite_count}'",
                    'description'   => "One of JPKole's test suites."
                 }
        new_suite = @tr_con.send_post(uri, fields)
        print "\tid:'#{new_suite['id']}'\n"
        @all_suites.push(new_suite['id'])
    end
    return
end


# ------------------------------------------------------------------------------
# Create a number of new TestRail sections.
#
def create_sections(sec_count)
    print "\n05) Creating '#{sec_count} sections; project='#{@new_project['name']}'  suite_id='#{@all_suites[0]}'\n"
    uri    = "add_section/#{@new_project['id']}"
    fields = {  'description'   => 'description: New section created by JPKole util.',
                'suite_id'      => @all_suites[0],
                'parent_id'     => nil,
                'name'          => 'name: New section created by JPKole util.'}
    (1..sec_count).each do |i|
        @new_section = @tr_con.send_post(uri, fields)
        print "\tid:'#{@new_section['id']}'\n"
    end
    return
end


# ------------------------------------------------------------------------------
# Create new TestRail testcases.
#
def create_testcases(tc_count)
return
    uri    = "add_case/???section_id???"
    fields = {  'name'                => new_proj_name,
                'announcement'        => "JPKole's new project anouncement.",
                'show_announcement'   => true,
                'suite_mode'          => 3}
    @new_project = @tr_con.send_post(uri, fields)
    print "\tid:'#{@new_project['id']}'  suite_mode:'#{@new_project['suite_mode']}'  announcement:'#{@new_project['announcement']}'\n"
    return
end


##########---MAIN---##########


bm_time = Benchmark.measure {
    get_testrail_connection()
    create_new_project("test-001")
    create_suites(5)
    create_sections(5)
    create_testcases(10)
}

print "This script (#{$PROGRAM_NAME}) is finished; benchmark time in seconds:\n"
print "  --User--   -System-   --Total-  --Elapsed-\n"
puts bm_time.to_s

#exit (0)

#[the end]#



#[the end]#
