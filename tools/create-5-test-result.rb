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


def get_known_case_types()
    case_types = @tr_con.send_get('get_case_types')
    print "\n----------------------------------------------\n"
    print "03) Known case types (* = default):\n"
    case_types.sort_by { |rec| rec['id']}.each do |this_CT|
        if this_CT['is_default'] == true
            prefix = '*'
        else
            prefix = ' '
        end
        print "\t#{prefix} #{this_CT['id']} #{this_CT['name']}\n"
    end
end


def get_case()
    case_id     = 1
    this_CASE   = @tr_con.send_get("get_case/#{case_id}")

    print "Test Case found:\n"
    print "\tID   : #{this_CASE['section_id']}\n" 
    print "\tTitle: #{this_CASE['title']}\n" 
end


#
# Connect to TestRail system.
#
get_my_vars()
get_testrail_connection()
get_known_case_types()

tn = Time.now

run_id=1
case_id=1
(1..5).each do |count|
  r = @tr_con.send_post("add_result_for_case/#{run_id}/#{case_id}",
                        {
                            :status_id      => 1,
                            :comment        => "Result (#{count}) @ #{tn}",
                            :version        => '3.14',
                            :elpased        => '1m 4s',
                            :defects        => '',
                            :assignedto_id  => 1,
                        }
                      )
  print "\tResult created: case_id='#{case_id}'  run_id='#{run_id}'"
  print "  test_id='#{r['test_id']}'  status_id='#{r['status_id']}'  comment='#{r['comment']}'\n"
end 

#[the end]#
