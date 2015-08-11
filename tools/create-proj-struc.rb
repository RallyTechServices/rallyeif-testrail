#!/usr/bin/env ruby
# ============================================================================ #
# Script:
#       create-proj-struc.rb
# Purpose:
#       To create a new test project in TesRail with this structure:
#
#       Project
#           Suite1
#               Section1a
#                   Testcase1a-1
#                   Testcase1a-2
#               Section1b
#                   Testcase1b-1
#                   Testcase1b-2
#           Suite2
#               Section2a
#                   Testcase2a-1
#                   Testcase2a-2
#               Section2b
#                   Testcase2b-1
#                   Testcase2b-2
# ============================================================================ #

$my_testrail_url        = 'https://tsrally.testrail.com'
$my_testrail_user       = 'user@company.com'
$my_testrail_password   = 'MySecretPassword'

#unless $LOAD_PATH.include?(File.dirname(__FILE__) + "/lib/" )
#    $LOAD_PATH.unshift(File.expand_path("#{File.dirname(__FILE__)}/lib/") )
#end



# ------------------------------------------------------------------------------
# Check that we have access to the required Ruby GEM(s).
#
%w{benchmark ./lib/testrail-api-master/ruby/testrail.rb}.each do |this_Require|
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


# ------------------------------------------------------------------------------
# Define a TestRail connection.
#
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
def create_project(new_proj_name)

    # Be sure the project does not already exist.
    uri = 'get_projects'
    @all_projs = @tr_con.send_get(uri)
    if @all_projs.length > 0
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
    uri    = 'add_project'
    fields = {  'name'                => new_proj_name,
                'announcement'        => "JPKole's new project anouncement.",
                'show_announcement'   => true,
                'suite_mode'          => 3}
    print "\n03) Creating project: '#{fields['name']}'\n"
    @new_project = @tr_con.send_post(uri, fields)
        # Returns:
        #       {"id"=>54,
        #        "name"=>"JP-Test-Project-001",
        #        "announcement"=>"JPKole's new project anouncement.",
        #        "show_announcement"=>true,
        #        "is_completed"=>false,
        #        "completed_on"=>nil,
        #        "suite_mode"=>3,
        #        "url"=>"https://tsrally.testrail.com/index.php?/projects/overview/54"}
    print "\tid:'#{@new_project['id']}'  suite_mode:'#{@new_project['suite_mode']}'  announcement:'#{@new_project['announcement']}'\n"
    return
end


# ------------------------------------------------------------------------------
# Create a number of new TestRail suites.
#
def create_suites(suite_count)
    @all_suites     = Array.new
    @all_suite_ids  = Array.new
    print "\n04) Creating '#{suite_count}' suites in project: '#{@new_project['name']}'\n"
    (1..suite_count).each do |next_suite|
        uri    = "add_suite/#{@new_project['id']}"
        fields = {  'name'          => "Suite #{next_suite} of #{suite_count}",
                    'description'   => "One of JPKole's test suites."}
        new_suite = @tr_con.send_post(uri, fields)
            # Returns:
			#		{"id"=>97,
			#		 "name"=>"Suite '1' of '5'",
			#		 "description"=>"One of JPKole's test suites.",
			#		 "project_id"=>55,
			#		 "is_master"=>false,
			#		 "is_baseline"=>false,
			#		 "is_completed"=>false,
			#		 "completed_on"=>nil,
			#		 "url"=>"https://tsrally.testrail.com/index.php?/suites/view/97"}
        print "\tid:'#{new_suite['id']}'  name:'#{new_suite['name']}'\n"
        @all_suites.push(new_suite)
        @all_suite_ids.push(new_suite['id'])
    end
    return
end


# ------------------------------------------------------------------------------
# Create a number of new TestRail sections in each suite.
#
def create_suite_sections(sections_per_suite)
    print "\n05) Creating '#{sections_per_suite}' sections in each of the '#{@all_suites.length}' suites #{@all_suite_ids}\n"
    @all_sections       = Array.new
    @all_section_ids    = Array.new
    uri    = "add_section/#{@new_project['id']}"
    fields = {  'description'   => "JPKole's new section; 'x' of 'y' in suite '#{}'",
                'suite_id'      => 0,
                'parent_id'     => nil,
                'name'          => "JPKole's new section; 'x' of 'y' in suite '#{}'"}
    @all_suites.each do |next_suite|
        (1..sections_per_suite).each do |sec|
            fields['name']     = "JPKole's new section; #{sec} of #{sections_per_suite} in suite #{next_suite['id']}"
            fields['suite_id'] = next_suite['id']
            begin
                new_section = @tr_con.send_post(uri, fields)
                # Returns:
			    #		{"id"=>2412,
			    #		 "suite_id"=>101,
			    #		 "name"=>"name: New section created by JPKole util.",
			    #		 "description"=>"description: New section created by JPKole util.",
			    #		 "parent_id"=>nil,
			    #		 "display_order"=>1,
			    #		 "depth"=>0}
            rescue Exception => ex
                print "EXCEPTION occurred on TestRail API 'send_post(#{uri}, #{fields})':\n"
                print "\t#{ex.message}\n"
                raise UnrecoverableException.new("\tFailed to find new TestRail testcases", self)
            end
            print "\tid:'#{new_section['id']}'  name:'#{new_section['name']}\n"
            @all_sections.push(new_section)
            @all_section_ids.push(new_section['id'])
        end
    end
    return
end


# ------------------------------------------------------------------------------
# Create a number of new TestRail testcases in each section.
#
def create_section_testcases(tc_per_sec)
    print "\n06) Creating '#{tc_per_sec}' test cases in each of the '#{@all_sections.length}' sections #{@all_section_ids}\n"
    @all_cases      = Array.new
    @all_case_ids   = Array.new
    fields = {  'title'         => "JPKole's new test case; 'X' of 'Y' in section 'Z'",
                'type_id'       => 6,   # 6=Other
                'priority_id'   => 1,   # 4=Must test
                'estimate'      => '30s',
                'milestone_id'  => nil,
                'refs'          => nil}
    @all_sections.each do |next_section|
        (1..tc_per_sec).each do |next_case|
            uri             = "add_case/#{next_section['id']}"
            fields['title'] = "JPKole's new test case; #{next_case} of #{tc_per_sec} in section #{next_section['id']}"
            begin
                new_case = @tr_con.send_post(uri, fields)
                # Returns a new case:
			    #		{"id"=>15191,
			    #		 "title"=>"title: Jpkole's new test case.",
			    #		 "section_id"=>2397,
			    #		 "type_id"=>6,
			    #		 "priority_id"=>4,
			    #		 "milestone_id"=>nil,
			    #		 "refs"=>nil,
			    #		 "created_by"=>1,
			    #		 "created_on"=>1438201297,
			    #		 "updated_by"=>1,
			    #		 "updated_on"=>1438201297,
			    #		 "estimate"=>"30s",
			    #		 "estimate_forecast"=>nil,
			    #		 "suite_id"=>75,
			    #		 "custom_rallyurl"=>nil,
			    #		 "custom_rallyformattedid"=>nil,
			    #		 "custom_rallyobjectid"=>nil,
			    #		 "custom_preconds"=>nil,
			    #		 "custom_steps"=>nil,
			    #		 "custom_expected"=>nil}
            rescue Exception => ex
                print "EXCEPTION occurred on TestRail API 'send_post(#{uri}, #{fields})':\n"
                print "\t#{ex.message}\n"
                raise UnrecoverableException.new("\tFailed to create a new testcase in section '#{next_section['id']}'", self)
            end
            print "\tid:'#{new_case['id']}'  title:'#{new_case['title']}\n"
            @all_cases.push(new_case)
            @all_case_ids.push(new_case['id'])
        end
        print "\t----\n"
    end
    return
end


# ------------------------------------------------------------------------------
# Create a number of new Runs.
#
def create_runs()
    print "\n07) Creating runs...\n"
    @all_runs       = Array.new
    @all_run_ids    = Array.new

    #---------------------------------------------------------
    suite_id = @all_suites[0]['id']
    print "\tcreating 1 run in suite_id '#{suite_id}' with all test cases which are in the same suite...\n"
    uri    = "add_run/#{@new_project['id']}"
    fields = {  'suite_id'      => suite_id,
                'name'          => 'My test run name 1',
                'description'   => 'My test run description 1',
                'milestone_id'  => nil,
                'assigned_to'   => nil,
                'include_all'   => true,
                'case_ids'      => nil}
    begin
        new_run = @tr_con.send_post(uri, fields)
        # Returns:
		#		{"id"=>200,
		#		 "suite_id"=>266,
		#		 "name"=>"My test run name",
		#		 "description"=>"My test run description",
		#		 "milestone_id"=>nil,
		#		 "assignedto_id"=>nil,
		#		 "include_all"=>true,
		#		 "is_completed"=>false,
		#		 "completed_on"=>nil,
		#		 "config"=>nil,
		#		 "config_ids"=>[],
		#		 "passed_count"=>0,
		#		 "blocked_count"=>0,
		#		 "untested_count"=>8,
		#		 "retest_count"=>0,
		#		 "failed_count"=>0,
		#		 "custom_status1_count"=>0,
		#		 "custom_status2_count"=>0,
		#		 "custom_status3_count"=>0,
		#		 "custom_status4_count"=>0,
		#		 "custom_status5_count"=>0,
		#		 "custom_status6_count"=>0,
		#		 "custom_status7_count"=>0,
		#		 "project_id"=>95,
		#		 "plan_id"=>nil,
		#		 "created_on"=>1438630002,
		#		 "created_by"=>1,
		#		 "url"=>"https://tsrally.testrail.com/index.php?/runs/view/200"}
    rescue Exception => ex
        print "EXCEPTION occurred on TestRail API 'send_post(#{uri}, #{fields})':\n"
        print "\t#{ex.message}\n"
        raise UnrecoverableException.new("\tFailed to create a new run in the suite", self)
    end
    print "\trun id:'#{new_run['id']}'  name:'#{new_run['name']}\n"
    @all_runs.push(new_run)
    @all_run_ids.push(new_run['id'])

    #---------------------------------------------------------
    suite_id = @all_suites[1]['id']
    print "\tcreating 1 run in suite_id '#{suite_id}' with 2 test cases which are in the same suite...\n"
    uri    = "add_run/#{@new_project['id']}"
    fields = {  'suite_id'      => suite_id,
                'name'          => 'My test run name 2',
                'description'   => 'My test run description 2',
                'milestone_id'  => nil,
                'assigned_to'   => nil,
                'include_all'   => false,
                'case_ids'      => [@all_cases[2]['id'],@all_cases[3]['id']]}
    begin
        new_run = @tr_con.send_post(uri, fields)
    rescue Exception => ex
        print "EXCEPTION occurred on TestRail API 'send_post(#{uri}, #{fields})':\n"
        print "\t#{ex.message}\n"
        raise UnrecoverableException.new("\tFailed to create a new run in the suite", self)
    end
    print "\trun id:'#{new_run['id']}'  name:'#{new_run['name']}\n"
    @all_runs.push(new_run)
    @all_run_ids.push(new_run['id'])

    return
end


# ------------------------------------------------------------------------------
# Create a number of new TestPlans.
#
def create_plans(plan_count)
    @all_plans      = Array.new
    @all_plan_ids   = Array.new
    print "\n08) Creating '#{plan_count}' plans in project: '#{@new_project['name']}'\n"
    (1..plan_count).each do |next_plan|
        uri    = "add_plan/#{@new_project['id']}"
        fields = {  'name'          => "Plan #{next_plan} of #{plan_count}",
                    'description'   => "One of JPKole's test plans.",
                    'milestone_id'  => nil,
                    'entries'       => []}
        begin
            new_plan = @tr_con.send_post(uri, fields)
            # Returns:
		    #		{"id"=>223,
		    #		 "name"=>"Plan 1 of 4",
		    #		 "description"=>"One of JPKole's test plans.",
		    #		 "milestone_id"=>nil,
		    #		 "assignedto_id"=>nil,
		    #		 "is_completed"=>false,
		    #		 "completed_on"=>nil,
		    #		 "passed_count"=>0,
		    #		 "blocked_count"=>0,
		    #		 "untested_count"=>0,
		    #		 "retest_count"=>0,
		    #		 "failed_count"=>0,
		    #		 "custom_status1_count"=>0,
		    #		 "custom_status2_count"=>0,
		    #		 "custom_status3_count"=>0,
		    #		 "custom_status4_count"=>0,
		    #		 "custom_status5_count"=>0,
		    #		 "custom_status6_count"=>0,
		    #		 "custom_status7_count"=>0,
		    #		 "project_id"=>108,
		    #		 "created_on"=>1438706249,
		    #		 "created_by"=>1,
		    #		 "url"=>"https://tsrally.testrail.com/index.php?/plans/view/223",
		    #		 "entries"=>[]}
        rescue Exception => ex
            print "EXCEPTION occurred on TestRail API 'send_post(#{uri}, #{fields})':\n"
            print "\t#{ex.message}\n"
            raise UnrecoverableException.new("\tFailed to create a new TestPlan", self)
        end
        print "\tid:'#{new_plan['id']}'  name:'#{new_plan['name']}\n"
        @all_plans.push(new_plan)
        @all_plan_ids.push(new_plan['id'])
    end
    return
end


# ------------------------------------------------------------------------------
# Retrieve the Configuration information.
#
def get_configs()
    print "\n09) Retrieving the configurations defined...\n"
    @all_configs    = Array.new
    @all_config_ids = Array.new
    uri = "get_configs/#{@new_project['id']}"
    begin
        config_info = @tr_con.send_get(uri)
    rescue Exception => ex
        print "EXCEPTION occurred on TestRail API 'send_post(#{uri}, #{fields})':\n"
        print "\t#{ex.message}\n"
        raise UnrecoverableException.new("\tFailed to retrieve Configuration information", self)
    end
    return
end


# ------------------------------------------------------------------------------
# Create a number of Plan entries.
#
def create_plan_entries(pe_count)
    print "\n10) Creating '#{pe_count}' plan entries for each of '#{@all_plans.length}' plans...\n"
    @all_planentries        = Array.new
    @all_planentries_ids    = Array.new

    @all_plans.each do |next_plan|
        uri    = "add_plan_entry/#{next_plan['id']}"
        fields = {  'suite_id'      => @all_suite_ids[0],
                    'name'          => 'This is the PlanEntry name',
                    'assignedto_id' => nil,
                    'include_all'   => false,
                    'case_ids'      => [1,2,3,4],
                    'config_ids'    => [],
                    'runs'          => nil}
        begin
            new_plan_entry = @tr_con.send_post(uri, fields)
            # Returns:
			#		{"id"=>"bf13d407-1c13-4d9f-a7e8-ae714801eeb1",
			#		 "runs"=>
			#		  [{"id"=>317,
			#		    "suite_id"=>336,
			#		    "name"=>"This is the PlanEntry name",
			#		    "description"=>nil,
			#		    "milestone_id"=>nil,
			#		    "assignedto_id"=>nil,
			#		    "include_all"=>false,
			#		    "is_completed"=>false,
			#		    "completed_on"=>nil,
			#		    "passed_count"=>0,
			#		    "blocked_count"=>0,
			#		    "untested_count"=>0,
			#		    "retest_count"=>0,
			#		    "failed_count"=>0,
			#		    "custom_status1_count"=>0,
			#		    "custom_status2_count"=>0,
			#		    "custom_status3_count"=>0,
			#		    "custom_status4_count"=>0,
			#		    "custom_status5_count"=>0,
			#		    "custom_status6_count"=>0,
			#		    "custom_status7_count"=>0,
			#		    "project_id"=>129,
			#		    "plan_id"=>313,
			#		    "entry_index"=>1,
			#		    "entry_id"=>"bf13d407-1c13-4d9f-a7e8-ae714801eeb1",
			#		    "config"=>nil,
			#		    "config_ids"=>[],
			#		    "url"=>"https://tsrally.testrail.com/index.php?/runs/view/317"}],
			#		 "suite_id"=>336,
			#		 "name"=>"This is the PlanEntry name"}

        rescue Exception => ex
            print "EXCEPTION occurred on TestRail API during 'send_post'\n"
            print "\targ1: #{uri}\n"
            print "\targ2: #{fields}\n"
            print "\tmsg:  #{ex.message}\n"
            raise UnrecoverableException.new("\tFailed to create a new Plan Entry", self)
        end
        print "\tid:'#{new_plan_entry['id']}'  name:'#{new_plan_entry['name']}'  suite_id:'#{new_plan_entry['suite_id']}'\n"
        new_plan_entry['runs'].each do |next_run|
            print "\t\trun id:'#{next_run['id']}'  name:'#{next_run['name']}'  suite_id:'#{next_run['suite_id']}'  plan_id:'#{next_run['plan_id']}'\n"
        end
        @all_planentries.push(new_plan_entry)
        @all_planentries_ids.push(new_plan_entry['id'])
    end
    return
end


# ------------------------------------------------------------------------------
# Create a number of new Results.
#
def create_results
    print "\n11) Creating results...\n"
    @all_results    = Array.new
    @all_result_ids = Array.new

    #---------------------------------------------------------
    runid  = @all_runs[0]['id']
    caseid = @all_cases[0]['id']
    print "\tcreating 1 result for run-id='#{runid}', case_id='#{caseid}'...\n"
    uri    = "add_result_for_case/#{runid}/#{caseid}"
    fields = {  'status_id'     => 1, # 1-passed, 2-blocked, 3-untested, 4-retest, 5-failed
                'comment'       => 'Comment on my result #1',
                'version'       => 'Build12345',
                'elapsed'       => '314s',
                'defects'       => '1,2,3,4,5',
                'assigned_to'   => nil}
    begin
        new_result = @tr_con.send_post(uri, fields)
        # Returns:
		#		{"id"=>259,
		#		 "test_id"=>15498,
		#		 "status_id"=>1,
		#		 "created_by"=>1,
		#		 "created_on"=>1438632116,
		#		 "assignedto_id"=>nil,
		#		 "comment"=>"Comment on my result #1",
		#		 "version"=>"Build12345",
		#		 "elapsed"=>"5m 14s",
		#		 "defects"=>"1,2,3,4,5",
		#		 "custom_rallyobjectid"=>nil}
    rescue Exception => ex
        print "EXCEPTION occurred on TestRail API 'send_post(#{uri}, #{fields})':\n"
        print "\t#{ex.message}\n"
        raise UnrecoverableException.new("\tFailed to create a new result", self)
    end
    @all_results.push(new_result)
    @all_result_ids.push(new_result['id'])
    return
end


##########---MAIN---##########


bm_time = Benchmark.measure {
    get_testrail_connection()
    create_project("zJP-Test-Proj1x")
    create_suites(2)
    create_suite_sections(2)
    create_section_testcases(2)
    get_configs()
    create_plans(4)
    create_plan_entries(1)
    create_runs()
    create_results()

    print "\n12) Done:\n"
    print "\tProject      : #{@new_project['id']}\n"
    print "\t       suites: #{@all_suite_ids}\n"
    print "\t     sections: #{@all_section_ids}\n"
    print "\t    testcases: #{@all_case_ids}\n"
    print "\t        plans: #{@all_plan_ids}\n"
    print "\t plan entries: #{@all_planentries_ids}\n"
    print "\t         runs: #{@all_run_ids}\n"
    print "\t      results: #{@all_result_ids}\n"
}

print "\n13) This script (#{$PROGRAM_NAME}) is finished; benchmark time in seconds:\n"
print "  --User--   -System-   --Total-  --Elapsed-\n"
puts bm_time.to_s

exit (0)

#[the end]#
