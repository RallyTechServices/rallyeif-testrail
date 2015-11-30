#!/usr/bin/env ruby

require '../lib/testrail-api-master/ruby/testrail.rb'

$my_testrail_url        = 'https://tsrally.testrail.com'
$my_testrail_user       = 'user@company.com'
$my_testrail_password   = 'MySecretPassword'


def get_my_vars()
    print "\n01) -------------------------------------------\n"
    my_vars = './MyVars.rb'
    if FileTest.exist?( my_vars )
        print "\tSourcing #{my_vars}...\n"
        require my_vars
    else
        print "\tFile #{my_vars} not found; skipping require...\n"
    end
end


def get_testrail_connection()
    @tr_con         = nil
    @tr_case_types  = nil
    @tr_case_fields = nil

    print "\n02) -------------------------------------------\n"
    print "\tConnecting to TestRail system at:\n"
    print "\tURL  : #{$my_testrail_url}\n"
    print "\tUser : #{$my_testrail_user}\n"

    # ------------------------------------------------------------------
    # Set up a TestRail connection packet.
    #
    @tr_con          = TestRail::APIClient.new($my_testrail_url)
    @tr_con.user     = $my_testrail_user
    @tr_con.password = $my_testrail_password

    print "\n03) -------------------------------------------\n"
    print "\tConnected to the TestRail system:\n"
    print "\tuser:#{@tr_con.user}\n"
end


def get_case(case_id)
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
    print "\n04) -------------------------------------------\n"
    print "\tTest case number '#{case_id}' fields:\n"
    print "\tord  field name                value\n"
    print "\t---  ------------------------  --------------------------------------\n"
    this_case.each_with_index do |keyval, ndx|
        key = keyval[0]
        val = keyval[1]
        # Deal with dates:
        val = "#{val} (#{Time.at(val)})" if key == 'created_on'
        val = "#{val} (#{Time.at(val)})" if key == 'updated_on'
        val = val.dump                   if key == 'title'
        val = val.dump                   if key == 'custom_preconds'
        print "\t%3d  %-24s  %s\n"%[ndx+1,key,val]
    end
end


##########---MAIN---##########

if ARGV[0].nil?
    print "ERROR: One argument required:\n"
    print "Usage: #{$PROGRAM_NAME} <testcase_id>\n"
    exit -1
end

get_my_vars()
get_testrail_connection()
get_case(ARGV[0])

#[the end]#
