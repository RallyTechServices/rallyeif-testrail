Date: 20-Jul-2015
From: John P. Kole
Subj: How to install and use Rally's TestRail connector on CentOS - reldir-03

This document is composed of the following sections:
    A.) Overview:
    B.) Installation of RVM and Ruby:
    C.) Installation of the TestRail connector GEMs:
    D.) Create custom fields in Rally and TestRail:
    E.) Testing the TestRail connector:
    F.) Running a simple demo with the TestRail connector:


A.) Overview:
    01) This connector release consists of the following files:
            (please see section C-01 below for a listing of archive contents)


    02) This connnector was tested on Ruby version ruby-2.1.5,
        on CentOS Linux release 7.0.1406 (Core).


    03) This connector code was developed on MAC-OS (OS X Yosemite - 10.10).


    04) This installation will use RVM to manage Ruby (https://rvm.io/rvm/install).

    
B.) Installation of RVM and Ruby:
    01) As a normal user, install RVM:
            - Command:
                $ \curl -sSL https://get.rvm.io | bash -s stable --ruby
            - Output:
                Downloading https://github.com/wayneeseguin/rvm/archive/1.26.11.tar.gz
                Downloading https://github.com/wayneeseguin/rvm/releases/download/1.26.11/1.26.11.tar.gz.asc
                Found PGP signature at: 'https://github.com/wayneeseguin/rvm/releases/download/1.26.11/1.26.11.tar.gz.asc',
                but no GPG software exists to validate it, skipping.

                Upgrading the RVM installation in /Users/jpkole/.rvm/
                    RVM PATH line found in /Users/jpkole/.profile /Users/jpkole/.bashrc /Users/jpkole/.zshrc.
                    RVM sourcing line found in /Users/jpkole/.bash_profile /Users/jpkole/.zlogin.
                    Updating libyaml in /Users/jpkole/.rvm/usr to version 0.1.6,
                        see https://github.com/wayneeseguin/rvm/issues/2594 ............|
                Upgrade of RVM in /Users/jpkole/.rvm/ is complete.


    02) Install the desired version of Ruby:
            - Command:
                $ rvm install ruby-2.1.5
            - Output:
                Searching for binary rubies, this might take some time.
                Found remote file https://rvm_io.global.ssl.fastly.net/binaries/osx/10.10/x86_64/ruby-2.1.5.tar.bz2
                Checking requirements for osx.
                Certificates in '/usr/local/etc/openssl/cert.pem' are already up to date.
                Requirements installation successful.
                ruby-2.1.5 - #configure
                ruby-2.1.5 - #download
                ruby-2.1.5 - #validate archive
                ruby-2.1.5 - #extract
                ruby-2.1.5 - #validate binary
                ruby-2.1.5 - #setup
                ruby-2.1.5 - #gemset created /Users/jpkole/.rvm/gems/ruby-2.1.5@global
                ruby-2.1.5 - #importing gemset /Users/jpkole/.rvm/gemsets/global.gems..............................
                ruby-2.1.5 - #generating global wrappers........
                ruby-2.1.5 - #gemset created /Users/jpkole/.rvm/gems/ruby-2.1.5
                ruby-2.1.5 - #importing gemsetfile /Users/jpkole/.rvm/gemsets/default.gems evaluated to empty gem list
                ruby-2.1.5 - #generating default wrappers........


    03) Tell rvm which version of Ruby we are going to use:
            - Command:
                $ rvm use ruby-2.1.5
            - Output:
                Using /Users/jpkole/.rvm/gems/ruby-2.1.5


    04) Create a "gemset" to be used with the TestRail connector (a "gemset" is basically a collection of Ruby
        "Libraries" that wwork together and may be revision dependant):
            - Command:
                $ rvm gemset create TestRail-4.0.0-ruby-2.1.5
            - Output:
                ruby-2.1.5 - #gemset created /Users/jpkole/.rvm/gems/ruby-2.1.5@TestRail-4.0.0-ruby-2.1.5
                ruby-2.1.5 - #generating TestRail-4.0.0-ruby-2.1.5 wrappers........


    05) Tell rvm which gemset we want to use:
            - Command:
                $ rvm gemset use TestRail-4.0.0-ruby-2.1.5
            - Output:
                Using ruby-2.1.5 with gemset TestRail-4.0.0-ruby-2.1.5


    06) We can see our gemsets and which one is active:
            - Command:
                $ rvm gemset list
            - Output:
                gemsets for ruby-2.1.5 (found in /Users/jpkole/.rvm/gems/ruby-2.1.5)
                   (default)
                => TestRail-4.0.0-ruby-2.1.5
                   global
                   rallyeif-wrk-0.5.5


    07) When done, the default installed GEMs are (this is the minimal set one gets with Ruby):
            - Command:
                $ gem list
            - Output:

                *** LOCAL GEMS ***

                bigdecimal (1.2.4)
                bundler (1.7.6)
                bundler-unload (1.0.2)
                executable-hooks (1.3.2)
                gem-wrappers (1.2.7)
                io-console (0.4.2)
                json (1.8.1)
                minitest (4.7.5)
                psych (2.0.5)
                rake (10.1.0)
                rdoc (4.1.0)
                rubygems-bundler (1.4.4)
                rvm (1.11.3.9)
                test-unit (2.1.5.0)


C.) Installation of the TestRail connector and the Ruby GEMs:
    01) Extract the ZIP file provided into a work area (like your home folder):
            - Command:
                $ unzip reldir-03.zip 
            - Output:
                Archive:  reldir-03.zip
                   creating: reldir-03/
                   creating: reldir-03/configs/
                  inflating: reldir-03/configs/Connections-test.xml  
                  inflating: reldir-03/configs/JP-VCE-demo-testcase.xml  
                  inflating: reldir-03/configs/JP-VCE-demo-testresult.xml  
                  inflating: reldir-03/Gemfile       
                   creating: reldir-03/gems/
                  inflating: reldir-03/gems/activesupport-4.2.1.gem  
                  inflating: reldir-03/gems/httpclient-2.4.0.gem  
                  inflating: reldir-03/gems/i18n-0.7.0.gem  
                  inflating: reldir-03/gems/mime-types-2.4.3.gem  
                  inflating: reldir-03/gems/mini_portile-0.6.2.gem  
                  inflating: reldir-03/gems/minitest-5.5.1.gem  
                  inflating: reldir-03/gems/multipart-post-2.0.0.gem  
                  inflating: reldir-03/gems/nokogiri-1.6.6.2.gem  
                  inflating: reldir-03/gems/rally_api-1.1.2.gem  
                  inflating: reldir-03/gems/rallyeif-testrail-4.0.0.gem  
                  inflating: reldir-03/gems/rallyeif-wrk-0.5.5.gem  
                  inflating: reldir-03/gems/rdoc-4.2.0.gem  
                  inflating: reldir-03/gems/thread_safe-0.3.5.gem  
                  inflating: reldir-03/gems/tzinfo-1.2.2.gem  
                  inflating: reldir-03/gems/xml-simple-1.1.5.gem  
                  inflating: reldir-03/gems/z-uninstall_all.txt  
                   creating: reldir-03/lib/
                   creating: reldir-03/lib/testrail-api-master/
                  inflating: reldir-03/lib/testrail-api-master/license.md  
                  inflating: reldir-03/lib/testrail-api-master/readme.md  
                   creating: reldir-03/lib/testrail-api-master/ruby/
                  inflating: reldir-03/lib/testrail-api-master/ruby/readme.md  
                  inflating: reldir-03/lib/testrail-api-master/ruby/testrail.rb  
                  inflating: reldir-03/lib/testrail-api-master/testrail-api-master.zip  
                  inflating: reldir-03/ReadMe-Demo.txt  
                  inflating: reldir-03/ReadMe.txt    

    02) Install the GEMs provided with the new TestRail connector:
            - Command (runs about 2 minutes):
                $ cd reldir-03/gems
                $ gem install --local *.gem
                $ cd ../..
            - Output:
                19 gems installed
                Successfully installed i18n-0.7.0
                Successfully installed thread_safe-0.3.5
                Successfully installed tzinfo-1.2.2
                Successfully installed minitest-5.5.1
                Successfully installed activesupport-4.2.1
                Parsing documentation for i18n-0.7.0
                Installing ri documentation for i18n-0.7.0
                Parsing documentation for thread_safe-0.3.5
                Installing ri documentation for thread_safe-0.3.5
                Parsing documentation for tzinfo-1.2.2
                Installing ri documentation for tzinfo-1.2.2
                Parsing documentation for minitest-5.5.1
                Installing ri documentation for minitest-5.5.1
                Parsing documentation for activesupport-4.2.1
                Installing ri documentation for activesupport-4.2.1
                Done installing documentation for i18n, thread_safe, tzinfo, minitest, activesupport after 9 seconds
                Successfully installed httpclient-2.4.0
                Parsing documentation for httpclient-2.4.0
                Installing ri documentation for httpclient-2.4.0
                Done installing documentation for httpclient after 2 seconds
                Successfully installed i18n-0.7.0
                Parsing documentation for i18n-0.7.0
                Done installing documentation for i18n after 0 seconds
                Successfully installed mime-types-2.4.3
                Parsing documentation for mime-types-2.4.3
                Installing ri documentation for mime-types-2.4.3
                Done installing documentation for mime-types after 0 seconds
                Successfully installed mini_portile-0.6.2
                Parsing documentation for mini_portile-0.6.2
                Installing ri documentation for mini_portile-0.6.2
                Done installing documentation for mini_portile after 0 seconds
                Successfully installed minitest-5.5.1
                Parsing documentation for minitest-5.5.1
                Done installing documentation for minitest after 0 seconds
                Successfully installed multipart-post-2.0.0
                invalid options: -SHN
                (invalid options are ignored)
                Parsing documentation for multipart-post-2.0.0
                Installing ri documentation for multipart-post-2.0.0
                Done installing documentation for multipart-post after 0 seconds
                Building native extensions.  This could take a while...
                Successfully installed nokogiri-1.6.6.2
                Parsing documentation for nokogiri-1.6.6.2
                Installing ri documentation for nokogiri-1.6.6.2
                Done installing documentation for nokogiri after 3 seconds
                Successfully installed rally_api-1.1.2
                Parsing documentation for rally_api-1.1.2
                Installing ri documentation for rally_api-1.1.2
                Done installing documentation for rally_api after 0 seconds
                Successfully installed rallyeif-wrk-0.5.5
                Successfully installed rallyeif-testrail-4.0.0
                Parsing documentation for rallyeif-wrk-0.5.5
                Installing ri documentation for rallyeif-wrk-0.5.5
                Parsing documentation for rallyeif-testrail-4.0.0
                Installing ri documentation for rallyeif-testrail-4.0.0
                Done installing documentation for rallyeif-wrk, rallyeif-testrail after 2 seconds
                Successfully installed rallyeif-wrk-0.5.5
                Parsing documentation for rallyeif-wrk-0.5.5
                Done installing documentation for rallyeif-wrk after 1 seconds
                Depending on your version of ruby, you may need to install ruby rdoc/ri data:

                <= 1.8.6 : unsupported
                 = 1.8.7 : gem install rdoc-data; rdoc-data --install
                 = 1.9.1 : gem install rdoc-data; rdoc-data --install
                >= 1.9.2 : nothing to do! Yay!
                Successfully installed rdoc-4.2.0
                Parsing documentation for rdoc-4.2.0
                Installing ri documentation for rdoc-4.2.0
                Done installing documentation for rdoc after 11 seconds
                Successfully installed thread_safe-0.3.5
                Parsing documentation for thread_safe-0.3.5
                Done installing documentation for thread_safe after 0 seconds
                Successfully installed tzinfo-1.2.2
                Parsing documentation for tzinfo-1.2.2
                Done installing documentation for tzinfo after 0 seconds
                Successfully installed xml-simple-1.1.5
                Parsing documentation for xml-simple-1.1.5
                Installing ri documentation for xml-simple-1.1.5
                Done installing documentation for xml-simple after 0 seconds
                20 gems installed

    03) When done, the list of installed Ruby GEMs should look like:
            - Command:
                $ gem list
            - Output:

                *** LOCAL GEMS ***

                activesupport (4.2.1)
                bigdecimal (1.2.4)
                bundler (1.9.1)
                bundler-unload (1.0.2)
                executable-hooks (1.3.2)
                gem-wrappers (1.2.7)
                httpclient (2.4.0)
                i18n (0.7.0)
                io-console (0.4.2)
                json (1.8.1)
                mime-types (2.4.3)
                mini_portile (0.6.2)
                minitest (5.5.1, 4.7.5)
                multipart-post (2.0.0)
                nokogiri (1.6.6.2)
                psych (2.0.5)
                rake (10.1.0)
                rally_api (1.1.2)
                rallyeif-testrail (4.0.0)
                rallyeif-wrk (0.5.5)
                rdoc (4.2.0, 4.1.0)
                rubygems-bundler (1.4.4)
                rvm (1.11.3.9)
                test-unit (2.1.5.0)
                thread_safe (0.3.5)
                tzinfo (1.2.2)
                xml-simple (1.1.5)

    04) Verify the connector was installed:
            - Commands:
                $ cd reldir-03
                > rally2_testrail_connector.rb  --version
            - Output:
                Work Item Connector Hub version 0.5.5-ts3pm2
                Rally Spoke version 4.4.10 using rally_api gem version 1.1.2
                TestRailConnection version 4.0.0-ts1


D.) Create custom fields in Rally and TestRail:
    01) The following Rally custom fields are used by the connector:
        Object     Name                 Display Name      Type
        ---------  -------------------  --------------    -------     --------
        Test Case  TestRailID           TestRailID        String      Required
        User Story TestRailPlanID       TestRailPlanID    String      Required

    02) The following TestRail custom fields are used by the connector:
        Object       Label                System Name       Type
        -----------  -------------------  --------------    ----------  --------
        Test Result  RallyObjectID        rallyobjectid     String      Required
        Test Case    RallyObjectID        rallyobjectid     String      Required
        Test Case    RallyFormattedID     rallyformattedid  String      Optional
        Test Case    RallyURL             rallyurl          Url (Link)  Optional


E.) Testing the TestRail connector:
    01) Edit a configuration file (such as the "configs/Connections-test.xml"
        provided) and adjust it for your environment.

    02) Run the connector:
            - Command:
                $ rally2_testrail_connector.rb  configs/Connections-test.xml  -1
            - Output:
                The output will be in the file "rallylog.log".


F.) Running a simple demo with the TestRail connector:
    01) See the document "ReadMe-Demo.txt" for an overview of running a more
        indepth test of the connector.

[the end]
