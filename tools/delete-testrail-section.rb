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


#
# Connect to TestRail system.
#
get_my_vars()
get_testrail_connection()

print "\n----------------------------------------------\n"
section_id = ARGV[0]
print "03) Get information on section #{section_id}:\n"
uri = "get_section/#{section_id}"
begin
    section_info = @tr_con.send_get(uri)
rescue Exception => ex
    print "\tEXCEPTION occurred on TestRail API 'send_get(#{uri})':\n"
    print "\t#{ex.message}\n"
    print "\tFailed to get information about TestRail section '#{section_id}'\n"
    exit -1
end
puts "\t" + section_info.inspect



print "\n----------------------------------------------\n"
print "03) Deleting section #{section_id}:\n"
uri = "delete_section/#{section_id}"
begin
    response = @tr_con.send_post(uri,nil)
rescue Exception => ex
    print "\tEXCEPTION occurred on TestRail API 'send_get(#{uri},nil)':\n"
    print "\t#{ex.message}\n"
    print "\tFailed to delete TestRail section '#{section_id}'\n"
    exit -1
end
if response.empty?
    print "\tSuccessfully deleted section '#{section_id}'\n"
else
    print "\tInternal error???\n"
end


#[the end]#
