#!/usr/bin/env ruby

require './lib/testrail-api-master/ruby/testrail.rb'

$my_testrail_url        = 'https://tsrally.testrail.com'
$my_testrail_user       = 'user@company.com'
$my_testrail_password   = 'MySecretPassword'

# ------------------------------------------------------------------------------
# Load (and maybe override with) my personal/private variables from a file.
#
my_vars = "./show-test-plan-tree.vars.rb"
if FileTest.exist?( my_vars )
    print "Sourcing #{my_vars}...\n"
    require my_vars
else
    print "File #{my_vars} not found; skipping require...\n"
end


# ------------------------------------------------------------------------------
# Connect to TestRail.
#
@tr_con         = nil
@tr_case_types  = nil
@tr_case_fields = nil

@tr_con          = TestRail::APIClient.new($my_testrail_url)
@tr_con.user     = $my_testrail_user
@tr_con.password = $my_testrail_password

print "\n----------------------------------------------\n"
print "01) Will Connect to TestRail system with:\n"
print "\t     URL : #{$my_testrail_url}\n"
print "\t    User : #{$my_testrail_user}\n"
print "\tPassword : #{$my_testrail_password.gsub(/./,'*')}\n"


# ------------------------------------------------------------------
# Find my desired project
#
my_proj_name = 'JP-VCE-sm3'
my_proj_name = 'zzJPKole-TestProject'
print "\n----------------------------------------------\n"
print "02) Searching for project: '#{my_proj_name}'\n"
my_proj_info = nil

uri = 'get_projects'
all_PROJECTs = @tr_con.send_get(uri)
if all_PROJECTs.length > 0
    all_PROJECTs.each do |item|
        if item['name'] == my_proj_name
            my_proj_info = item
            break
        end
    end
end
if my_proj_info == nil
    print "ERROR: Could not find project named: '#{my_proj_name}'\n"
    exit
end
p = my_proj_info
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


# ------------------------------------------------------------------
# Find all plans in the project.
#
uri = "get_plans/#{my_proj_info['id']}"
all_plans = @tr_con.send_get(uri)
    # Returns several:
    #   {"id"=>193, "name"=>"Test Plan Gamma (for 3rd Rally Story, but nil now)", "description"=>nil,
    #    "milestone_id"=>nil, "assignedto_id"=>nil, "is_completed"=>false, "completed_on"=>nil,
    #    "passed_count"=>1, "blocked_count"=>1, "untested_count"=>1, "retest_count"=>1, "failed_count"=>1,
    #    "custom_status1_count"=>1, "custom_status2_count"=>0, "custom_status3_count"=>0, "custom_status4_count"=>0,
    #    "custom_status5_count"=>0, "custom_status6_count"=>0, "custom_status7_count"=>0, "project_id"=>26,
    #    "created_on"=>1437573585, "created_by"=>1, "url"=>"https://tsrally.testrail.com/index.php?/plans/view/193"}
if all_plans.length < 1
    print "Found no plans for this project."
else
    print "\n----------------------------------------------\n"
    print "03) Found '#{all_plans.length}' Plans in the Project:\n"
    all_plans.each do |plan|
        print "\tid=#{plan['id']}  name=#{plan['name']}  is_completed=#{plan['is_completed']}\n"
        print "\t\t(passed,blocked,untested,retest,failed)_count="
        ['passed','blocked','untested','retest','failed'].each_with_index do |n,ndx|
            print "," if ndx != 0
            rn = n + '_count'
            print "#{plan[rn]}"
        end
        print "\n"

        # ----------------------------------------------------------
        # Get more details about this plan.
        #
        uri = "get_plan/#{plan['id']}"
        this_plan = @tr_con.send_get(uri)
            # Returns:
            #   {"id"=>193, "name"=>"Test Plan Gamma (for 3rd Rally Story, but nil now)", "description"=>nil,
            #    "milestone_id"=>nil, "assignedto_id"=>nil, "is_completed"=>false, "completed_on"=>nil,
            #    "passed_count"=>1, "blocked_count"=>1, "untested_count"=>1, "retest_count"=>1, "failed_count"=>1,
            #    "custom_status1_count"=>1, "custom_status2_count"=>0, "custom_status3_count"=>0, "custom_status4_count"=>0,
            #    "custom_status5_count"=>0, "custom_status6_count"=>0, "custom_status7_count"=>0,
            #    "project_id"=>26, "created_on"=>1437573585, "created_by"=>1, "url"=>"https://tsrally.testrail.com/index.php?/plans/view/193",
            #    "entries"=>[
            #       {"id"=>"4065784c-d591-4f56-8461-6ac41513abeb", "suite_id"=>26, "name"=>"Test Run 1 - Gamma",
            #           "runs"=>[
            #               {"id"=>194, "suite_id"=>26, "name"=>"Test Run 1 - Gamma", "description"=>nil,
            #                "milestone_id"=>nil, "assignedto_id"=>nil, "include_all"=>false, "is_completed"=>false, "completed_on"=>nil,
            #                "passed_count"=>1, "blocked_count"=>1, "untested_count"=>1, "retest_count"=>1, "failed_count"=>1,
            #                "custom_status1_count"=>1, "custom_status2_count"=>0, "custom_status3_count"=>0, "custom_status4_count"=>0,
            #                "custom_status5_count"=>0, "custom_status6_count"=>0, "custom_status7_count"=>0,
            #                "project_id"=>26, "plan_id"=>193, "entry_index"=>1, "entry_id"=>"4065784c-d591-4f56-8461-6ac41513abeb",
            #                "config"=>nil, "config_ids"=>[], "url"=>"https://tsrally.testrail.com/index.php?/runs/view/194"
            #               }]
            #       }]}
            #
            #   "entries" is:  An array of 'entries', i.e. group of test runs
        if this_plan.length < 1
            print "ERROR: TestPlan had no details returned.\n"
            exit
        end
        print "\t\tFound '#{this_plan['entries'].length}' entries (groups of test runs):\n"
        this_plan['entries'].each do |tr|
            print "\t\t\tid=#{tr['id']}\n"
            print "\t\t\t\tFound '#{tr['runs'].length}' runs:\n"
            tr['runs'].each do |run|
                print "\t\t\t\tid=#{run['id']}  name=#{run['name']}  is_completed=#{run['is_completed']}\n"
                print "\t\t\t\t(passed,blocked,untested,retest,failed)_count="
                ['passed','blocked','untested','retest','failed'].each_with_index do |n,ndx|
                    print "," if ndx != 0
                    rn = n + '_count'
                    print "#{plan[rn]}"
                end
                print "\n"
                print "\t\t\t\tconfig_ids=#{run['config_ids']}\n"
            end
        end
    end
end


# ------------------------------------------------------------------
# All done.
#
print "\n----------------------------------------------\n"
print "Done.\n"


#[the end]#
