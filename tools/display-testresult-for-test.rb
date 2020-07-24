#!/usr/bin/env ruby

  def indent(val, count, char = ' ')
    val.gsub(/([^\n]*)(\n|$)/) do |match|
      last_iteration = ($1 == "" && $2 == "")
      line = ""
      line << (char * count) unless last_iteration
      line << $1
      line << $2
      line
    end
  end


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


def get_test_statuses()
    uri = 'get_statuses'
    @tr_test_statuses = @tr_con.send_get(uri)
    @tr_test_statuses_a = Array.new
    @tr_test_statuses.each do |ts|
        @tr_test_statuses_a[ts['id']] = ts['label']
    end
    @tr_test_statuses_a[0] = @tr_test_statuses_a.length - 1
end


def get_test(test_id)
    uri = "get_test/#{test_id}"
    this_test = @tr_con.send_get(uri)
    print "\n04) -------------------------------------------\n"
    print "\tFound Test Id '#{test_id}':\n"
    this_test.each_with_index do |this_field, ndx|
        label = this_field[0]
        value = this_field[1]
        #value = "#{value} (#{Time.at(value)})"              if label == 'created_on'
        #value = "#{value} (#{Time.at(value)})"              if label == 'updated_on'
        #value = value.dump                                  if label == 'comment'
        #value = "#{value}(#{@tr_test_statuses_a[value]})"   if label == 'status_id'
        print "\t%3d  %-21s  %s\n"%[ndx+1,label,value]
    end
end


def get_results(test_id)
    uri = "get_results/#{test_id}"
    all_results = @tr_con.send_get(uri)
    print "\n05) -------------------------------------------\n"
    print "\tFound '#{all_results.length}' Results for Test Id '#{test_id}':\n"

    all_results.each_with_index do |this_result, this_result_ndx|
        print "\tResult #{this_result_ndx+1}-of-#{all_results.length} for Test number '#{test_id}' fields:\n"
        print "\tord  field name             value\n"
        print "\t---  ---------------------  --------------------------------------\n"
        this_result.each_with_index do |this_field, ndx|
            label = this_field[0]
            value = this_field[1]
            value = "#{value} (#{Time.at(value)})"              if label == 'created_on'
            value = "#{value} (#{Time.at(value)})"              if label == 'updated_on'
            value = value.dump                                  if label == 'comment'
            value = "#{value}(#{@tr_test_statuses_a[value]})"   if label == 'status_id'
            print "\t%3d  %-21s  %s\n"%[ndx+1,label,value]
        end
        print "\n"
    end

end


##########---MAIN---##########

if ARGV[0].nil?
    print "ERROR: At least one argument required:\n"
    print "Usage: #{$PROGRAM_NAME} <test_id> [... <test_id>]\n"
    exit -1
end

get_my_vars()
get_testrail_connection()
get_test_statuses()

ARGV.each_with_index do |this_test_id|
    get_test(this_test_id)
    get_results(this_test_id)
end

#[the end]#
