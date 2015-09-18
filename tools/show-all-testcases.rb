#!/usr/bin/env ruby

require '../lib/testrail-api-master/ruby/testrail.rb'

$my_testrail_url        = 'https://somewhere.testrail.com'
$my_testrail_user       = 'user@company.com'
$my_testrail_password   = 'MySecretPassword'

# ------------------------------------------------------------------------------
# Load (and maybe override with) my personal/private variables from a file.
#
my_vars = './show-all-testcases.vars.rb'
if FileTest.exist?( my_vars )
    print "Sourcing #{my_vars}...\n"
    require my_vars
else
    print "File #{my_vars} not found; skipping require...\n"
end


@all_PROJECT = nil


#---01---#
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

#---02---#
    print "\n02) Connected to the TestRail system:\n"
    print "\tuser:#{@tr_con.user}\n"
end


#---03---#
def get_projects()
    uri = 'get_projects'
    all_projects = @tr_con.send_get(uri)
    print "\n03) Total Projects found: '#{all_projects.length}'\n"
    if all_projects.length > 0
        @suites = Hash.new
        print "\tid   name                  suite_mode  is_completed  completed_on\n"
        print "\t---  --------------------  ----------  ------------  --------------------------------------\n"
        all_projects.each do |next_project|
            print "\t%3d"   %   [next_project['id']]
            print "  %-20s" %   [next_project['name']]
            print "  %-10d" %   [next_project['suite_mode']]
            print "  %-12s" %   [next_project['is_completed']]
            print "  %s"    %   [next_project['completed_on']]
            if !next_project['completed_on'].nil?
                print " (%s)"       %   [Time.at(next_project['completed_on'])]
            end
            print "\n"
            if next_project['suite_mode'] == 3
                ################ suites
                @suites[next_project['id']] = @tr_con.send_get("get_suites/#{next_project['id']}").to_a
                print "\t\tFound '#{@suites[next_project['id']].length}' suites in above project:\n"
                @suites[next_project['id']].each do |sweet|
                    print "\t\t\tsuite id=#{sweet['id']}, name=#{sweet['name']}\n"
                    ################ sections
                    uri = "get_sections/#{next_project['id']}&suite_id=#{sweet['id']}"
                    all_sections = @tr_con.send_get(uri)
                    print "\t\t\t\tFound '#{all_sections.length}' sections in above suite:\n"
                    all_sections.each do |next_section|
                        # {"id"=>1, "suite_id"=>1, "name"=>"All Test Cases", "description"=>nil, "parent_id"=>nil, "display_order"=>1, "depth"=>0}
                        print "\t\t\t\t\tid='#{next_section['id']}'  name='#{next_section['name']}'  description='#{next_section['description']}'\n"
                        ################ cases
                        uri = "get_cases/#{next_project['id']}&suite_id=#{sweet['id']}&section_id=#{next_section['id']}"
                        all_cases = @tr_con.send_get(uri)
                        print "\t\t\t\t\tFound '#{all_cases.length}' cases in above section:\n"
                        all_cases.each_with_index do |next_case,ndx|
                            char=','
                            if ndx == 0
                                print "\t\t\t\t\t\tids="
                                char='('
                            end
                            print "#{char}#{next_case['id']}"
                            if all_cases.size-1 == ndx
                                print ")\n"
                            end
                        end
                        ################
                    end
                    ################
                end
                ################
            end
        print "\t---  --------------------  ----------  ------------  --------------------------------------\n"
        end
    end
    return all_projects
end


#---04---#
def get_desired_proj (dp_name,all_projects)
    target_proj = nil
    all_projects.each do |this_PROJECT|
        if this_PROJECT['name'] == dp_name
            target_proj = this_PROJECT
        end
    end
    
    print "\n04) Looking for desired project: '#{dp_name}'...\n"
    if target_proj.nil?
        if all_projects.length > 0
            target_proj = all_projects[0]
        else
            print "ERROR: No projects to search through... exiting...\n"
            exit
        end
        print "\tCan't find desired project '#{dp_name}'; will use first project found instead.\n"
    end
    print "\tUsing desired project '#{target_proj['name']} (id=#{target_proj['id']})'.\n"

    return target_proj
end


#---05---#
def get_case_fields()
    # ------------------------------------------------------------------
    # Get test case custom fields.
    #
    uri = 'get_case_fields'
    @tr_case_fields  = @tr_con.send_get(uri)
    print "\n05) Test case custom fields:\n"
    print "\t                                                                             display global/\n"
    print "\tid             name         type_id             system_name            label  _order      projIDs\n"
    print "\t-- ---------------- --------------- ----------------------- ---------------- ------- ------------\n"
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


#---06---#
def get_result_fields()
    # ------------------------------------------------------------------
    # Get result custom fields.
    #
    uri = 'get_result_fields'
    @tr_result_fields  = @tr_con.send_get(uri)
    print "\n06) Result custom fields:\n"
    print "\t                                                                             display global/\n"
    print "\tid             name         type_id             system_name            label  _order  projIDs\n"
    print "\t-- ---------------- --------------- ----------------------- ---------------- ------- --------\n"
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


#---07---#
def get_priorities()
    # ------------------------------------------------------------------
    # Get known priorities
    #
    uri = 'get_priorities'
    @tr_priorities = @tr_con.send_get(uri)
        # { "id"        =>1,
        #   "name"      =>"1 - Don't Test",
        #   "short_name"=>"1 - Don't",
        #   "is_default"=>false,
        #   "priority"  =>1}
    print "\n07) Known priorities (* = default):\n"
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


#---08---#
def get_case_types
    # ------------------------------------------------------------------
    # Get known case types.
    #
    uri = 'get_case_types'
    @tr_case_types   = @tr_con.send_get(uri)
        #{  "id"=>1,
        #   "name"=>"Automated",
        #   "is_default"=>false}
    print "\n08) Known test case types (* = default):\n"
    @tr_case_types.sort_by { |rec| rec['id']}.each do |this_CT|
        if this_CT['is_default'] == true
            prefix = '*'
        else
            prefix = ' '
        end
        print "\t#{prefix} #{this_CT['id']} #{this_CT['name']}\n"
    end
end


#---09---#
def get_test_statuses()
    uri = 'get_statuses'
    @tr_test_statuses   = @tr_con.send_get(uri)
        #  {"id"=>3,
        #   "name"=>"untested",
        #   "label"=>"Untested",
        #   "color_dark"=>11579568,
        #   "color_medium"=>15395562,
        #   "color_bright"=>15790320,
        #   "is_system"=>true,
        #   "is_untested"=>true,
        #   "is_final"=>false},
    print "\n09) Known test statuses:\n"
    print "\t  id  name            label\n"
    print "\t  --  --------------  --------\n"
    @tr_test_statuses.each do |this_ST|
        print "\t  %-2d"%[this_ST['id']]
        print "  %-14s"%[this_ST['name']]
        print "  %-8s"%[this_ST['label']]
        print "\n"
    end
end


#---10---#
def get_cases(target_proj, section_id:'')
    suite_list = Array.new
    uri = "get_cases/#{target_proj['id']}&suite_id="
    case target_proj['suite_mode']
    when 1
        suite_list = ['']
    when 2
        puts 'ERROR: suite_mode 2 is not yet implemented'
        exit -1
    when 3
        @suites[target_proj['id']].each do |suite|
            suite_list.push(suite['id'])
        end
    else
        puts 'ERROR: suite_mode is not 1, 2 or 3'
        exit -1
    end
    print "\n10) Find all cases in all suites (#{suite_list})\n"
    all_cases = Array.new
    suite_list.each do |suite_id|
        uri = "get_cases/#{target_proj['id']}&suite_id=#{suite_id}&section_id=#{section_id}"
        cases = @tr_con.send_get(uri)
require 'byebug';byebug
        print "\ttest cases found (#{suite_id}): #{cases.length}"
        if cases.length > 0
            cases.each_with_index do |item, ndx|
                if ndx == 0
                    print " ("
                else
                    print "," if ndx != cases.length
                end
                print "#{item['id']}"
            end
            print ")\n"
        else
            print "\n"
        end
        all_cases.concat cases
    end
    return all_cases
end


#---11---#
def get_case(case_id:1)
    uri = "get_case/#{case_id}"
    this_case = @tr_con.send_get(uri)
        #{"id"                      => 397,
        # "title"                   => "Time-2015-01-09_08:08:00-678043",
        # "section_id"              => 1,
        # "type_id"                 => 6,
        # "priority_id"             => 5,
        # "milestone_id"            => 1,
        # "refs"                    => nil,
        # "created_by"              => 1,
        # "created_on"              => 1420816081,
        # "updated_by"              => 1,
        # "updated_on"              => 1420816083,
        # "estimate"                => "3m",
        # "estimate_forecast"       => "3m",
        # "suite_id"                => 1,
        # "custom_rallyobjectid"    => "32147483647",
        # "custom_rallyurl"         => nil,
        # "custom_rallyformattedid" => nil,
        # "custom_proj_one_only"    => nil,
        # "custom_preconds"         => nil,
        # "custom_steps"            => nil,
        # "custom_expected"         => nil}
    print "\n11) Test case number '#{case_id}' fields:\n"
    print "\tord  field name                value\n"
    print "\t---  ------------------------  --------------------------------------\n"
    this_case.each_with_index do |keyval, ndx|
        key = keyval[0]
        val = keyval[1]
        # Deal with dates:
        val = "#{val} (#{Time.at(val)})" if key == 'created_on'
        val = "#{val} (#{Time.at(val)})" if key == 'updated_on'
        print "\t%3d  %-24s  %s\n"%[ndx+1,key,val]
    end
end


#---12---#
def get_plans(target_proj)
    uri = "get_plans/#{target_proj['id']}"
    @all_plans = @tr_con.send_get(uri)
    print "\n12) Found '#{@all_plans.length}' Plans for project '#{target_proj['id']}':\n"
    @all_plans.each_with_index do |item,ndx|
        if ndx == 0
            print "\tid   name                                                    created_on\n"
            print "\t---  ------------------------------------------------------  --------------------------------------\n"
        end
        print "\t%3d"%[item['id']]
        print "  %-54s"%[item['name']]
        print "  %10d (#{Time.at(item['created_on'])})"%[item['created_on']]
        print "\n"
    end
    return
end


#---13---#
def get_runs_not_in_plan(target_proj)
    uri = "get_runs/#{target_proj['id']}"
    all_runs = @tr_con.send_get(uri)
    print "\n13) Found '#{all_runs.length}' Runs for project '#{target_proj['id']}' which are not in a testplan:\n"
    all_runs.each_with_index do |item,ndx|
        if ndx == 0
            print "\t                                               project\n"
            print "\tid   name                                         id   created_on\n"
            print "\t---  ------------------------------------------  ----  --------------------------------------\n"
        end
        print "\t%3d"%[item['id']]
        print "  %-42s"%[item['name']]
        print "  %4d"%[item['project_id']]
        print "  %10d (#{Time.at(item['created_on'])})"%[item['created_on']]
        print "\n"
    end
    return all_runs.last
end


#---14---#
def get_runs_in_plans(target_proj)
    uri = "get_plans/#{target_proj['id']}"
    all_plans = @tr_con.send_get(uri)
#require 'pry';binding.pry
        # Returns plans; a plan:
		#		{"id"=>192,
		#		 "name"=>"Test Plan Beta (for 2nd Rally Story, but nil now)",
		#		 "description"=>nil,
		#		 "milestone_id"=>nil,
		#		 "assignedto_id"=>nil,
		#		 "is_completed"=>false,
		#		 "completed_on"=>nil,
		#		 "passed_count"=>1,
		#		 "blocked_count"=>1,
		#		 "untested_count"=>1,
		#		 "retest_count"=>0,
		#		 "failed_count"=>0,
		#		 "custom_status1_count"=>0,
		#		 "custom_status2_count"=>0,
		#		 "custom_status3_count"=>0,
		#		 "custom_status4_count"=>0,
		#		 "custom_status5_count"=>0,
		#		 "custom_status6_count"=>0,
		#		 "custom_status7_count"=>0,
		#		 "project_id"=>26,
		#		 "created_on"=>1437573544,
		#		 "created_by"=>1,
		#		 "url"=>"https://somewhere.testrail.com/index.php?/plans/view/192"}
    print "\n14) Find all runs in the '#{all_plans.length}' plans for project '#{target_proj['id']}':\n"
    all_plans.each do |plan|
        print "\tPlan id='#{plan['id']}'  name='#{plan['name']}'\n"
        uri = "get_plan/#{plan['id']}"
        plan = @tr_con.send_get(uri)
            # Returns a plan:
		    #		{"id"=>193,
		    #		 "name"=>"Test Plan Gamma (for 3rd Rally Story, but nil now)",
		    #		 "description"=>nil,
		    #		 "milestone_id"=>nil,
		    #		 "assignedto_id"=>nil,
		    #		 "is_completed"=>false,
		    #		 "completed_on"=>nil,
		    #		 "passed_count"=>1,
		    #		 "blocked_count"=>1,
		    #		 "untested_count"=>1,
		    #		 "retest_count"=>1,
		    #		 "failed_count"=>1,
		    #		 "custom_status1_count"=>1,
		    #		 "custom_status2_count"=>0,
		    #		 "custom_status3_count"=>0,
		    #		 "custom_status4_count"=>0,
		    #		 "custom_status5_count"=>0,
		    #		 "custom_status6_count"=>0,
		    #		 "custom_status7_count"=>0,
		    #		 "project_id"=>26,
		    #		 "created_on"=>1437573585,
		    #		 "created_by"=>1,
		    #		 "url"=>"https://somewhere.testrail.com/index.php?/plans/view/193",
		    #		 "entries"=>
		    #		  [{"id"=>"4065784c-d591-4f56-8461-6ac41513abeb",
		    #		    "suite_id"=>26,
		    #		    "name"=>"Test Run 1 - Gamma",
		    #		    "runs"=>
		    #		     [{"id"=>194,
		    #		       "suite_id"=>26,
		    #		       "name"=>"Test Run 1 - Gamma",
		    #		       "description"=>nil,
		    #		       "milestone_id"=>nil,
		    #		       "assignedto_id"=>nil,
		    #		       "include_all"=>false,
		    #		       "is_completed"=>false,
		    #		       "completed_on"=>nil,
		    #		       "passed_count"=>1,
		    #		       "blocked_count"=>1,
		    #		       "untested_count"=>1,
		    #		       "retest_count"=>1,
		    #		       "failed_count"=>1,
		    #		       "custom_status1_count"=>1,
		    #		       "custom_status2_count"=>0,
		    #		       "custom_status3_count"=>0,
		    #		       "custom_status4_count"=>0,
		    #		       "custom_status5_count"=>0,
		    #		       "custom_status6_count"=>0,
		    #		       "custom_status7_count"=>0,
		    #		       "project_id"=>26,
		    #		       "plan_id"=>193,
		    #		       "entry_index"=>1,
		    #		       "entry_id"=>"4065784c-d591-4f56-8461-6ac41513abeb",
		    #		       "config"=>nil,
		    #		       "config_ids"=>[],
		    #		       "url"=>"https://somewhere.testrail.com/index.php?/runs/view/194"}]}]}
        print "\t\tfound '#{plan['entries'].length}' entries:\n"
        plan['entries'].each do |e|
            print "\t\tEntry id='#{e['id']}'  name='#{e['name']}'  config_ids='#{e['config_ids']}'\n"
            print "\t\t\tContains '#{e['runs'].length}' runs:\n"
            e['runs'].each do |next_run|
                print "\t\t\t\tid='#{next_run['id']}'\n"
                uri = "get_results_for_run/#{next_run['id']}"
                results = @tr_con.send_get(uri)
#require 'pry';binding.pry
                    # Returns:
					#		 [{"id"=>255,
					#		  "test_id"=>15391,
					#		  "status_id"=>6,
					#		  "created_by"=>1,
					#		  "created_on"=>1437574436,
					#		  "assignedto_id"=>nil,
					#		  "comment"=>nil,
					#		  "version"=>nil,
					#		  "elapsed"=>nil,
					#		  "defects"=>nil,
					#		  "custom_rallyobjectid"=>nil},
                    #
					#		 {"id"=>254,
					#		  "test_id"=>15390,
					#		  "status_id"=>5,
					#		  "created_by"=>1,
					#		  "created_on"=>1437574212,
					#		  "assignedto_id"=>nil,
					#		  "comment"=>nil,
					#		  "version"=>nil,
					#		  "elapsed"=>nil,
					#		  "defects"=>nil,
					#		  "custom_rallyobjectid"=>nil},
                    #
                    #       .....
                    print "\t\t\t\t\twith '#{results.length}' results:\n"
                    results.each do |next_result|
                        print "\t\t\t\t\tid='#{next_result['id']}'  custom_rallyobjectid='#{next_result['custom_rallyobjectid']}'\n"
                    end
            end
        end
    end
    return
end


#---15---#
def get_results(test_id: 6)
    uri = "get_results/#{test_id}"
    all_results = @tr_con.send_get(uri)
    print "\n15) Found '#{all_results.length}' Results for Test Id '#{test_id}':\n"
    print "\tid  test_id  status_id  created_on                              custom_rallyobjectid\n"
    print "\t--  -------  ---------  --------------------------------------  --------------------\n"
    all_results.each do |item|
        print "\t%2d"       %   [item['id']]
        print "  %7d"       %   [item['test_id']]
        print "  %9d"       %   [item['status_id']]
        print "  %10d (#{Time.at(item['created_on'])})" %   [item['created_on']]
        print "  %s"        %   [item['custom_rallyobjectid']]
        print "\n"
        
    end
end


##########---MAIN---##########

get_testrail_connection()
all_projects = get_projects()
dp='Test-Proj-sm3'
dp='JP-VCE-sm3'
dp='zJP-Test-Proj1'
target_proj = get_desired_proj(dp,all_projects)
get_case_fields()
get_result_fields()
get_priorities()
get_case_types()
get_test_statuses()
lc = get_cases(target_proj)
if !lc.nil?
    get_case(case_id:lc[0]['id'])
end
get_plans(target_proj)
get_runs_not_in_plan(target_proj)
get_runs_in_plans(target_proj)
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
