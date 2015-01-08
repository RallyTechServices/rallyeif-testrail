#!/usr/bin/env ruby

require './testrail-api-master/ruby/testrail.rb'

$my_testrail_url        = 'https://somewhere.testrail.com'
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
        all_PROJECTs.each_with_index do |this_PROJECT, ndx|
            print "\tid:'#{this_PROJECT['id']}'  name:'#{this_PROJECT['name']}'  url:'#{this_PROJECT['url']}'\n"
        end
    end
    return all_PROJECTs.last
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

        if this_CF['configs'][0].to_hash['context']['is_global'] == true
            gpids = [true]
        else 
            gpids = this_CF['configs'][0].to_hash['context']['project_ids']
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
    print "\n05) Known priorities (* = default):\n"
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
    print "\n06) Known test case types (* = default):\n"
    @tr_case_types.sort_by { |rec| rec['id']}.each do |this_CT|
        if this_CT['is_default'] == true
            prefix = '*'
        else
            prefix = ' '
        end
        print "\t#{prefix} #{this_CT['id']} #{this_CT['name']}\n"
    end
end


def get_cases(project_id:1, suite_id:'', section_id:'')
    uri = "get_cases/#{project_id}&suite_id=#{suite_id}&section_id=#{section_id}"
    all_CASEs = @tr_con.send_get(uri)
    print "\n07) Total test cases found: #{all_CASEs.length}"
    if all_CASEs.length > 0
        all_CASEs.each_with_index do |this_CASE, ndx|
            if ndx == 0
                print "  ("
            else
                print "," if ndx != all_CASEs.length
            end
            print "#{this_CASE['id']}"
        end
        print ")\n"
    end
    return all_CASEs.last
end


def get_case(case_id: 1)
    uri = "get_case/#{case_id}"
    this_CASE = @tr_con.send_get(uri)
    print "\n08) Test case number '#{case_id}' fields:\n"
    print "\tord  field name              value\n"
    print "\t---  ----------------------  --------------------------------------\n"
    this_CASE.each_with_index do |keyval, ndx|
        key = keyval[0]
        val = keyval[1]
        # Deal with dates:
        val = "#{val} (#{Time.at(val)})" if key == 'created_on'
        val = "#{val} (#{Time.at(val)})" if key == 'updated_on'
        print "\t%3d  %-22s  %s\n"%[ndx+1,key,val]
    end
end


def get_runs(project_id:1)
    uri = "get_runs/#{project_id}"
    all_RUNs = @tr_con.send_get(uri)
    return all_RUNs.last
end



##########---MAIN---##########

get_testrail_connection()
get_projects()
get_case_fields()
get_priorities()
get_case_types()
lc = get_cases(project_id:1)
get_case(case_id:lc['id'])
get_runs()

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
