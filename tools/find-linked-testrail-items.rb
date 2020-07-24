#!/usr/bin/env ruby

require '../lib/testrail-api-master/ruby/testrail.rb'

$my_testrail_url        = 'https://tsrally.testrail.com'
$my_testrail_user       = 'technical-services@rallydev.com'
$my_testrail_password   = 'FooBar'
$my_testrail_project    = 'BarFoo'


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


def get_project_info()
    print "\n----------------------------------------------\n"
    print "03) Searching for project: '#{$my_testrail_project}'...\n"
    my_proj_info = nil

    uri = 'get_projects'
    begin
        all_PROJECTs = @tr_con.send_get(uri)
    rescue Exception => ex
        print "\tEXCEPTION occurred on TestRail API 'send_get(#{uri})':\n"
        print "\t#{ex.message}\n"
        print "\tFailed to get information about all TestRail projects'\n"
        exit -1
    end

    if all_PROJECTs.length > 0
        all_PROJECTs.each do |item|
            if item['name'] == $my_testrail_project
                @tr_proj_info = item
                break
            end
        end
    end
    if @tr_proj_info == nil
        print "ERROR: Could not find project named: '#{$my_testrail_project}'\n"
        exit
    end
    p = @tr_proj_info
    print "\tfound project:\n"
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
    @tr_proj_id = @tr_proj_info['id']

    uri = "get_suites/#{@tr_proj_id}"
    begin
        @tr_suites = @tr_con.send_get(uri)
    rescue Exception => ex
        print "\tEXCEPTION occurred on TestRail API 'send_get(#{uri})':\n"
        print "\t#{ex.message}\n"
        print "\tFailed to get information about all TestRail suites in project.\n"
        exit -1
    end
    suiteids = Array.new
    @tr_suites.each_with_index do |this_suite, index_suite|
        suiteids.push(this_suite['id'])
    end
    print "\n\tFound '#{@tr_suites.length}' suites in the project: ''#{suiteids}'\n"

    return @tr_proj_info, @tr_suites
end


def get_all_testcases()
    print "\n----------------------------------------------\n"
    print "04) Getting all TestRail testcases in project '#{$my_testrail_project}'...\n"

    @tr_testcases_per_suite = Array.new # each element is all testcase in a suite
    @tr_suites.each_with_index do |this_suite,index_suite|
        uri = "get_cases/#{@tr_proj_info['id']}&suite_id=#{this_suite['id']}"
        begin
            all_cases = @tr_con.send_get(uri)
        rescue Exception => ex
            print "\tEXCEPTION occurred on TestRail API 'send_get(#{uri})':\n"
            print "\t#{ex.message}\n"
            print "\tFailed to get TestRail testcases for suite '#{this_suite['id']}'\n"
            exit -1
        end
        print "\tFound '#{all_cases.length}' testcases in suite '#{this_suite['id']}'\n"
        @tr_testcases_per_suite.push(all_cases)
    end
    tots=0
    tc_oids = Hash.new
    @tr_testcases_per_suite.each_with_index do |this_tcset, index_tcset|
        #puts "set #{index_tcset+1} has '#{this_tcset.length}' testcases ---------------------"
        this_tcset.each_with_index do |this_case, index_case|
            #print "\t#{index_case+1} testcase id='#{this_case['id']}' RallyOID='#{this_case['rallyobjectid']}'\n"
            #if this_case['id'] == 28969
            #    require 'byebug';byebug
            #end
            found=false
            str = ''
            if !this_case['custom_rallyobjectid'].nil?
                str = str + " RallyOID='#{this_case['custom_rallyobjectid']}'"
                found=true
            end
            if !this_case['custom_rallyformattedid'].nil?
                str = str + " RallyFmtID='#{this_case['custom_rallyformattedid']}'"
                found=true
            end
            if !this_case['custom_rallyurl'].nil?
                str = str + " RallyURL='#{this_case['custom_rallyurl']}'"
                found=true
            end
            if !str.empty?
                tots+=1
            end
            print "\t #{tots} - testcase id='#{this_case['id']}'#{str}\n"

            #Try to find duplicates...
            if tc_oids[this_case['custom_rallyobjectid']] == true || tc_oids[this_case['custom_rallyformattedid']] == true
                puts "Found more than one TestRail testcase with same Rally OID"
            else
                tc_oids[this_case['custom_rallyobjectid']] = true
                tc_oids[this_case['custom_rallyformattedid']] = true
            end
        end
    end
    if tots < 1
        print "\tFound no TestRail TestCases with custom Rally field set.\n"
    else
        print "\tFound '#{tots}' TestRail TestCases with a custom Rally field set.\n"
    end
end

#
# Connect to TestRail system.
#
get_my_vars()
get_testrail_connection()
get_project_info()
get_all_testcases()
exit



#[the end]#
