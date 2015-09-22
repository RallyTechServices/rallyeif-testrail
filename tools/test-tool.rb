#!/usr/bin/env ruby

#
# Util used for modifying a Rally TestCaseResult to include a Rally TestSet.
#

$my_base_url    = 'https://demo-services1.rallydev.com/slm'
$my_username    = 'paul@acme.com'
$my_password    = 'RallyON!'
$my_workspace   = 'Integrations'
$my_version     = 'v2.0'

require 'rally_api'

# ------------------------------------------------------------------------------
# connect to rally
#
$my_headers = RallyAPI::CustomHttpHeader.new()
$my_headers.name    = 'test-tool.rb'
$my_headers.vendor  = 'JP code'
$my_headers.version = '3.14159'
config = {  :base_url   => $my_base_url,
            :username   => $my_username,
            :password   => $my_password,
            :workspace  => $my_workspace,
            :version    => $my_version,
            :headers    => $my_headers}
rally = RallyAPI::RallyRestJson.new(config)
print "Connected to Rally:\n"
print "\tBaseURL  : <#{$my_base_url}>\n"
print "\tUserName : <#{$my_username}>\n"
print "\tWorkspace: <#{$my_workspace}>\n"
print "\tVersion  : <#{$my_version}>\n"

# ------------------------------------------------------------------------------
# read the testcaseresult
#

# WS         : Integrations
# Project    : Fulfillment Team
# Build      : 113
# Name       : Test Case Result 2015-08-31 Pass
# TestCase   : WSAPI: TC1 - https://demo-services1.rallydev.com/slm/webservice/v2.0/testcase/1505660
#            : GUI  : TC1 - https://demo-services1.rallydev.com/#/723135d/detail/testcase/1505660
# WSAPI      : https://demo-services1.rallydev.com/slm/webservice/v2.0/testcaseresult/1505669
# GUI        : https://demo-services1.rallydev.com/#/723135d/detail/testcaseresult/1505669
tcr1_oid     = 1505669
#tcr1_ref    = "https://demo-services1.rallydev.com/slm/webservice/v2.0/testcaseresult/#{tcr1_oid}"

begin
    tcr_str = 'testcaseresult'
    print "Reading artifact='#{tcr_str}',  OID='#{tcr1_oid}'\n"
    tcr = rally.read(tcr_str, tcr1_oid)
    tcr1_ref = tcr._ref
require 'byebug';byebug
rescue Exception => ex
    print "ERROR: During rally.read; arg1='#{tcr_str}',  arg2='#{tcr1_oid}'\n"
    print "       Message returned: #{ex.message}\n"
end


# ------------------------------------------------------------------------------
# update with new testset
#

# Workspace  : Acme
# Project    : Shopping Team
# FormattedID: TS1
# Description: Test routine for firefox browser.
# Release    : Release 2 (5,6,7)
# Name       : Firefox Browser Tests
# TestCases  : TC1 - https://demo-services1.rallydev.com/slm/webservice/v2.0/testcase/1524088
#              TC2 - https://demo-services1.rallydev.com/slm/webservice/v2.0/testcase/1524097
#              TC4 - https://demo-services1.rallydev.com/slm/webservice/v2.0/testcase/1524115
#              TC8 - https://demo-services1.rallydev.com/slm/webservice/v2.0/testcase/1524145
#              TC9 - https://demo-services1.rallydev.com/slm/webservice/v2.0/testcase/1524151
# https://demo-services1.rallydev.com/slm/webservice/v2.0/testset/3594217
ts1_oid      = 3594217
ts1          = "https://demo-services1.rallydev.com/slm/webservice/v2.0/testset/#{ts1_oid}"

# TS1:
# Workspace  : CA - RPU - September 9-10 2015
# Project    : Agile Team 1
# FormattedID: TS1
# Description: Test routine for firefox browser
# Release    : PI Q3
# Name       : Firefox Browser Tests
# TestCases  : TC18 - https://demo-services1.rallydev.com/slm/webservice/v2.0/testcase/1495490
#            : TC19 - https://demo-services1.rallydev.com/slm/webservice/v2.0/testcase/1495509
#            : TC21 - https://demo-services1.rallydev.com/slm/webservice/v2.0/testcase/1495548
#            : TC25 - https://demo-services1.rallydev.com/slm/webservice/v2.0/testcase/1495614
#            : TC26 - https://demo-services1.rallydev.com/slm/webservice/v2.0/testcase/1495626
# https://demo-services1.rallydev.com/slm/webservice/v2.0/testset/3593905
ts2_oid      = 3593905
ts2          = "https://demo-services1.rallydev.com/slm/webservice/v2.0/testset/#{ts2_oid}"

ts3_oid      = 6200939
ts3          = "https://demo-services1.rallydev.com/slm/webservice/v2.0/testset/#{ts3_oid}"

begin
    fields_to_update = {
            'Notes'     => tcr.Notes + '<br/>' + "Updated: #{Time.now}",
            'TestSet'   => {'_ref'=>ts3}
    }
    print "Updating artifact='#{tcr_str}',  OID='#{tcr1_oid},  fields_to_update='#{fields_to_update}''\n"
    tcr.update(fields_to_update)
rescue Exception => ex
    print "ERROR: During tcr.update; arg1='#{fields_to_update}'\n"
    print "       Message: #{ex.message}\n"
end

#[the end]#
#	Error1 - when in diff workspace:
#	Connecting to Rally:
#	    BaseURL  : <https://demo-services1.rallydev.com/slm>
#	    UserName : <paul@acme.com>
#	    Workspace: <Integrations>
#	    Version  : <v2.0>
#	
#	ERROR: During tcr.update; arg1='{"Notes"  =>"JPKole 1<br/>Updated: 2015-09-10 14:09:46 -0600",
#	                                 "TestSet"=>{"_ref"=>"https://demo-services1.rallydev.com/slm/webservice/v2.0/testset/3593905"}}'
#	       Message: Error on request - https://demo-services1.rallydev.com/slm/webservice/v2.0/testcaseresult/1505669.js?/workspace=/workspace/722746 -
#	            {:errors=>["Could not set value for Test Set: Cannot connect object to value, Test Set value is in a different workspace.
#	                       [object workspace OID=722746, value workspace OID=711640"],
#	             :warnings=>["It is no longer necessary to append \".js\" to WSAPI resources."]}
#	


#	Error2 - when in diff project::
#   Connecting to Rally:
#       BaseURL  : <https://demo-services1.rallydev.com/slm>
#       UserName : <paul@acme.com>
#       Workspace: <Integrations>
#       Version  : <v2.0>
#       ERROR: During tcr.update; arg1='{"Notes"  =>"JPKole 1<br/>Updated: 2015-09-10 14:30:38 -0600",
#                                        "TestSet"=>{"_ref"=>"https://demo-services1.rallydev.com/slm/webservice/v2.0/testset/6200939"}}'
#              Message: Error on request - https://demo-services1.rallydev.com/slm/webservice/v2.0/testcaseresult/1505669.js?/workspace=/workspace/722746 - 
#               {:errors=  >["Could not set value for Test Set: null"],
#                :warnings=>["It is no longer necessary to append \".js\" to WSAPI resources."]}
