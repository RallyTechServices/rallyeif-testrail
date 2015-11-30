#!/usr/bin/env ruby

require '../lib/testrail-api-master/ruby/testrail.rb'

$my_testrail_url        = 'https://somewhere.testrail.com'
$my_testrail_user       = '***REMOVED***'
$my_testrail_password   = 'FooBar'


def get_my_vars()
    print "\n----------------------------------------------\n"
    my_vars = './MyVars.rb'
    if FileTest.exist?( my_vars )
        print "01) Sourcing #{my_vars}...\n"
        require my_vars
    else
        print "01) File #{my_vars} not found; skipping require...\n"
    end
end


def get_testrail_connection()
    print "\n----------------------------------------------\n"
    print "02) Connecting to TestRail system at:\n"
    print "\tURL  : #{$my_testrail_url}\n"
    print "\tUser : #{$my_testrail_user}\n"
    @tr_con          = TestRail::APIClient.new($my_testrail_url)
    @tr_con.user     = $my_testrail_user
    @tr_con.password = $my_testrail_password
    return @tr_con
end


def get_known_case_types()
    uri = 'get_case_types'
    @case_types = @tr_con.send_get(uri)
    print "\n----------------------------------------------\n"
    print "03) Known case types (* = default):\n"
    @case_types.sort_by { |rec| rec['id']}.each do |this_CT|
        if this_CT['is_default'] == true
            prefix = '*'
        else
            prefix = ' '
        end
        print "\t#{prefix} #{this_CT['id']} #{this_CT['name']}\n"
    end
end


def get_desired_project(desired_project)
    print "\n----------------------------------------------\n"
    print "04) Searching for project: '#{desired_project}'\n"
    @desired_project_info = nil

    uri = 'get_projects'
    all_PROJECTs = @tr_con.send_get(uri)
    if all_PROJECTs.length < 1
        print "No projects found... exting.\n"
        exit -1
    end
    all_PROJECTs.each do |this_project|
        if this_project['name'] == desired_project
            @desired_project_info = this_project
            break
        end
    end
    if @desired_project_info == nil
        print "ERROR: Could not find project named: '#{desired_project}'\n"
        exit
    end
    p = @desired_project_info # shorten the name for print lines below
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
    return @desired_project_info
end


def get_first_suite(project_id)
    uri = "get_suites/#{project_id}"
    @all_suites = @tr_con.send_get(uri)
    if @all_suites.length < 1
        print "Error: Found no suites in the above project."
        exit -1
    else
        print "\n----------------------------------------------\n"
        print "05) Found '#{@all_suites.length}' suites in above project; using first:\n\t"
        @all_suites.each_with_index do |this_suite,ndx_suite|
            print "#{this_suite['id']}  "
        end
        print "\n"
    end
    @first_suite = @all_suites.first
    return @first_suite
end


def get_first_section(project_id,suite_id)
    uri = "get_sections/#{project_id}&suite_id=#{suite_id}"
    @all_sections = @tr_con.send_get(uri)
    if @all_sections.length < 1
        print "Error: Found no sections in the above project."
        exit -1
    else
        print "\n----------------------------------------------\n"
        print "06) Found '#{@all_sections.length}' sections in above project; using first:\n\t"
        @all_sections.each_with_index do |this_section,ndx_section|
            print "#{this_section['id']}  "
        end
        print "\n"
    end
    @first_section = @all_sections.first
    return @first_section
end


def create_case(section_id)
    print "\n----------------------------------------------\n"
    print "07) Create a testcase in section id='#{section_id}':\n"
    (1..1).each do |count|
        tn = Time.now
        uri = "add_case/#{section_id}"
        this_case = @tr_con.send_post(uri,
                        {
                            :title          => "TestCase created @ #{tn}",
                            :type_id        => 1,
                            :priority_id    => 1,
                            :eastimate      => '3h',
                            :milestone_id   => nil,
                            :refs           => nil,
                        }
                      )
        print "\tTestCase created: case id='#{this_case['id']}',  title='#{this_case['title']}'\n"
    end 
end


#
# Connect to TestRail system.
#
get_my_vars()
get_testrail_connection()
get_known_case_types()
get_desired_project('zJP-Test-Proj1')
get_first_suite(@desired_project_info['id'])
get_first_section(@desired_project_info['id'],@first_suite['id'])
create_case(@first_section['id'])


#[the end]#
