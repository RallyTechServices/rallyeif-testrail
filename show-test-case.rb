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


def get_testrail_connection()
    @tr_con         = nil
    @tr_case_types  = nil
    @tr_case_fields = nil

    print "\n01) Connecting to TestRail system at:\n"
    print "\tURL  : #{$my_testrail_url}\n"
    print "\tUser : #{$my_testrail_user}\n"

    # ------------------------------------------------------------------
    # Set up a TestRail connection packet.
    #
    @tr_con          = TestRail::APIClient.new($my_testrail_url)
    @tr_con.user     = $my_testrail_user
    @tr_con.password = $my_testrail_password

    print "\n02) Connected to the TestRail system:\n"
    print "\tuser:#{@tr_con.user}\n"
end


def get_projects()
    uri = 'get_projects'
    all_PROJECTs = @tr_con.send_get(uri)
    print "\n03) Total Projects found: #{all_PROJECTs.length}\n"
    if all_PROJECTs.length > 0
        all_PROJECTs.each do |this_PROJECT|
            print "\tid:'#{this_PROJECT['id']}'"
            print "  suite_mode:'#{this_PROJECT['suite_mode']}'"
            print "  name:'#{this_PROJECT['name']}'"
            print "  url:'#{this_PROJECT['url']}'"
            print "\n"

            if this_PROJECT['suite_mode'] == 3
                returned_suites = @tr_con.send_get("get_suites/#{this_PROJECT['id']}")
                print "\t\tFound '#{returned_suites.length}' suites in above project:\n"
                returned_suites.each do |sweet|
                    print "\t\t\tsuite id=#{sweet['id']}, name=#{sweet['name']}\n"
                end
            end
        end
    end
    return all_PROJECTs
end

def get_desired_proj (dp_name,all_projects)
    target_proj = nil
    all_projects.each do |pj|
        if pj['name'] == dp_name
        target_proj = pj
        end
    end
    
    print "\n"
    if target_proj.nil?
        if all_projects.length > 0
            target_proj = all_projects[0]
        else
            print "exiting...\n"
            exit
        end
        print "\tCan't find desired project '#{dp_name}'; using project '#{target_proj['name']} (id=#{target_proj['id']})' instead (first project found).\n"
    else
        print "\tUsing desired project '#{target_proj['name']} (id=#{target_proj['id']})'.\n"
    end

    return target_proj
end


def get_case_fields()
    # ------------------------------------------------------------------
    # Get test case custom fields.
    #
    uri = 'get_case_fields'
    @tr_case_fields  = @tr_con.send_get(uri)
    print "\n04) Test case custom fields:\n"
    print "\t                                                     system                  display global/\n"
    print "\tid             name         type_id                   _name            label  _order projIDs\n"
    print "\t-- ---------------- --------------- ----------------------- ---------------- ------- -------\n"

    cf_types = ['',             # 0
                'String',       # 1
                'Integer',      # 2
                'Text',         # 3
                'URL',          # 4
                'Checkbox',     # 5
                'Dropdown',     # 6
                'User',         # 7
                'Date',         # 8
                'Milestone',    # 9
                'Steps',        # 10
                '?Unknown?',    # 11
                'Multi-select', # 12
                ]
    @tr_case_fields.sort_by { |rec| rec['id']}.each do |this_CF|
        print "\t%2d"%[this_CF['id']]
        print " %16s"%[this_CF['name']]

        tis="#{cf_types[this_CF['type_id']]}(#{this_CF['type_id']})"
        print " %15s"%[tis]

        print " %23s"%[this_CF['system_name']]
        print " %16s"%[this_CF['label']]
        print " %7s"%[this_CF['display_order']]
        
        if this_CF['configs'] == []
            gpids = '[unassigned]'
        else
            if this_CF['configs'][0].to_hash['context']['is_global'] == true
                gpids = '[global]'
            else 
                gpids = this_CF['configs'][0].to_hash['context']['project_ids'].to_s
            end
        end
        print " %s"%[gpids]

        print "\n"
    end
end


def get_result_fields()
    # ------------------------------------------------------------------
    # Get result custom fields.
    #
    uri = 'get_result_fields'
    @tr_result_fields  = @tr_con.send_get(uri)
    print "\n05) Result custom fields:\n"
    print "\t                                                     system                  display global/\n"
    print "\tid             name         type_id                   _name            label  _order projIDs\n"
    print "\t-- ---------------- --------------- ----------------------- ---------------- ------- -------\n"

    cf_types = ['',             # 0
                'String',       # 1
                'Integer',      # 2
                'Text',         # 3
                'URL',          # 4
                'Checkbox',     # 5
                'Dropdown',     # 6
                'User',         # 7
                'Date',         # 8
                'Milestone',    # 9
                'Steps',        # 10
                '?Unknown?',    # 11
                'Multi-select', # 12
                ]
    @tr_result_fields.sort_by { |rec| rec['id']}.each do |this_CF|
        print "\t%2d"%[this_CF['id']]
        print " %16s"%[this_CF['name']]

        tis="#{cf_types[this_CF['type_id']]}(#{this_CF['type_id']})"
        print " %15s"%[tis]

        print " %23s"%[this_CF['system_name']]
        print " %16s"%[this_CF['label']]
        print " %7s"%[this_CF['display_order']]
        
        if this_CF['configs'] == []
            gpids = '[unassigned]'
        else
            if this_CF['configs'][0].to_hash['context']['is_global'] == true
                gpids = '[global]'
            else 
                gpids = this_CF['configs'][0].to_hash['context']['project_ids'].to_s
            end
        end
        print " %s"%[gpids]

        print "\n"
    end
end


def get_priorities()
    # ------------------------------------------------------------------
    # Get known priorities
    #
    uri = 'get_priorities'
    @tr_priorities = @tr_con.send_get(uri)
    print "\n06) Known priorities (* = default):\n"
    print "\t  id  name              short_name    pri\n"
    print "\t  --  ----------------  ------------  ---\n"
    @tr_priorities.sort_by { |rec| rec['id']}.each do |this_PR|
        if this_PR['is_default'] == true
            prefix = '*'
        else
            prefix = ' '
        end
        print "\t#{prefix} %-2d"%[this_PR['id']]
        print "  %-16s"%[this_PR['name']]
        print "  %-12s"%[this_PR['short_name']]
        print "  %-3s"%[this_PR['priority']]
        print "\n"
    end
end


def get_case_types
    # ------------------------------------------------------------------
    # Get known case types.
    #
    uri = 'get_case_types'
    @tr_case_types   = @tr_con.send_get(uri)
    print "\n07) Known test case types (* = default):\n"
    @tr_case_types.sort_by { |rec| rec['id']}.each do |this_CT|
        if this_CT['is_default'] == true
            prefix = '*'
        else
            prefix = ' '
        end
        print "\t#{prefix} #{this_CT['id']} #{this_CT['name']}\n"
    end
end


def get_cases(target_proj, suite_id:'', section_id:'')
    uri = "get_cases/#{target_proj['id']}&suite_id=#{suite_id}&section_id=#{section_id}"
    all_cases = @tr_con.send_get(uri)
    print "\n08) Total test cases found: #{all_cases.length}"
    if all_cases.length > 0
        all_cases.each_with_index do |item, ndx|
            if ndx == 0
                print "  ("
            else
                print "," if ndx != all_cases.length
            end
            print "#{item['id']}"
        end
    end
    print "\n"
    return all_cases.last
end


def get_case(case_id:1)
    uri = "get_case/#{case_id}"
    puts "JPKOLE"
    this_case = @tr_con.send_get(uri)
        #{"id"						=> 397,
		# "title"					=> "Time-2015-01-09_08:08:00-678043",
		# "section_id"				=> 1,
		# "type_id"					=> 6,
		# "priority_id"				=> 5,
		# "milestone_id"			=> 1,
		# "refs"					=> nil,
		# "created_by"				=> 1,
		# "created_on"				=> 1420816081,
		# "updated_by"				=> 1,
		# "updated_on"				=> 1420816083,
		# "estimate"				=> "3m",
		# "estimate_forecast"		=> "3m",
		# "suite_id"				=> 1,
		# "custom_rallyobjectid"	=> 2147483647,
		# "custom_rallyurl"			=> nil,
		# "custom_rallyformattedid" => nil,
		# "custom_proj_one_only"	=> nil,
		# "custom_preconds"			=> nil,
		# "custom_steps"			=> nil,
		# "custom_expected"			=> nil}
    print "\n09) Test case number '#{case_id}' fields:\n"
    print "\tord  field name              value\n"
    print "\t---  ----------------------  --------------------------------------\n"
    this_case.each_with_index do |keyval, ndx|
        key = keyval[0]
        val = keyval[1]
        # Deal with dates:
        val = "#{val} (#{Time.at(val)})" if key == 'created_on'
        val = "#{val} (#{Time.at(val)})" if key == 'updated_on'
        print "\t%3d  %-22s  %s\n"%[ndx+1,key,val]
    end
end


def get_runs(target_proj)
    uri = "get_runs/#{target_proj['id']}"
    all_runs = @tr_con.send_get(uri)
        #[{"id"						=> 1,
        #  "suite_id"				=> 1,
        #  "name"					=> "Test Run 01 - 12/3/2014",
        #  "description"			=> "This is a ....",
        #  "milestone_id"			=> 1,
        #  "assignedto_id"			=> 1,
        #  "include_all"			=> true,
        #  "is_completed"			=> false,
        #  "completed_on"			=> nil,
        #  "config"					=> nil,
        #  "config_ids"				=> [],
        #  "passed_count"			=> 0,
        #  "blocked_count"			=> 0,
        #  "untested_count"			=> 16,
        #  "retest_count"			=> 0,
        #  "failed_count"			=> 0,
        #  "custom_status1_count"   => 0,
        #  "custom_status2_count"	=> 0,
        #  "custom_status3_count"	=> 0,
        #  "custom_status4_count"	=> 0,
        #  "custom_status5_count"	=> 0,
        #  "custom_status6_count"	=> 0,
        #  "custom_status7_count"	=> 0,
        #  "project_id"				=> 1,
        #  "plan_id"				=> nil,
        #  "created_on"				=> 1417639979,
        #  "created_by"				=> 1,
        #  "url"					=> "https://tsrally.testrail.com/index.php?/runs/view/1"}]
    print "\n10) Found '#{all_runs.length}' Runs for project '#{target_proj['id']}':\n"
    all_runs.each_with_index do |item,ndx|
        if ndx == 0
            print "\t                                                proj     created\n"
            print "\tid  name                                          id          on\n"
            print "\t--  ------------------------------------------  ----  ----------\n"
        end
        print "\t%2d"%[item['id']]
        print "  %-42s"%[item['name']]
        print "  %4d"%[item['project_id']]
        print "  %10d"%[item['created_on']]
        print "\n"
    end
    return all_runs.last
end


def get_results(test_id: 6)
    uri = "get_results/#{test_id}"
    all_results = @tr_con.send_get(uri)
        #{"id"			    	    => 79,
        # "test_id"		    	    => 6,
        # "status_id"	    	    => 1,
        # "created_by"	    	    => 1,
        # "created_on"	    	    => 1420833528,
        # "assignedto_id"           => 1,
        # "comment"		    	    => "JP testing",
        # "version"		    	    => "3.14",
        # "elapsed"		    	    => "1m 23s",
        # "defects"		    	    => nil,
        # "custom_rallyobjectid"    => nil}
    print "\n11) Found '#{all_results.length}' Results for Test Id '#{test_id}':\n"
    print "\t                                test     created\n"
    print "\tid  name                          id          on\n"
    print "\t--  --------------------------  ----  ----------\n"
    all_results.each do |item|
        print "\t%2d"%[item['id']]
        print "  %-26s"%[item['name']]
        print "  %4d"%[item['test_id']]
        print "  %10d"%[item['created_on']]
        print "\n"
    end
end


##########---MAIN---##########

get_testrail_connection()
all_projects = get_projects()
target_proj = get_desired_proj('Test-Proj-01', all_projects)
get_case_fields()
get_result_fields()
get_priorities()
get_case_types()
lc = get_cases(target_proj)
if !lc.nil?
    get_case(case_id:lc['id'])
end
get_runs(target_proj)
get_results()

exit

run_id = 1
case_id = lc['id']
uri = "get_results_for_case/#{run_id}/#{case_id}"

require 'debugger'
debugger

results = @tr_con.send_get(uri)
print "\nFound '#{results.length}' Results for Case.\n"

results.sort_by { |rec| rec['id']}.each do |this_RES|
  print "\t#{this_RES}\n"
end 

#[the end]#
