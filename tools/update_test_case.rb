#!/usr/bin/env ruby

require './testrail-api-master/ruby/testrail.rb'
require 'pp'

$my_testrail_url        = 'https://someone.testrail.com'
$my_testrail_user       = nil
$my_testrail_password   = nil

def get_testrail_connection()
    @tr_con         = nil
    @tr_case_types  = nil
    @tr_case_fields = nil

    print "Connecting to TestRail system at:\n"
    print "\tURL  : #{$my_testrail_url}\n"
    print "\tUser : #{$my_testrail_user}\n"

    @tr_con          = TestRail::APIClient.new($my_testrail_url)
    @tr_con.user     = $my_testrail_user
    @tr_con.password = $my_testrail_password
end

get_testrail_connection()

case_id     = 10
this_CASE   = @tr_con.send_get("get_case/#{case_id}")
pp this_CASE

int_work_item = '{"custom_rallyformattedid": "DE1234"}' # work way
int_work_item = {:custom_rallyformattedid => 'DE1234',}  # right way
print "Updating case '#{case_id}' with '#{int_work_item}'\n"
updated_item = @tr_con.send_post("update_case/#{case_id}", int_work_item)

#[the end]#
