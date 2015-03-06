Date: 05-Mar-2015
From: John P. Kole
Subj: How to install and use Rally's TestRail connector - reldir-01

This document is composed of the following sections:
    A.) Overview:
    B.) Installation of Ruby:
    C.) Installation of the TestRail connector GEMs:
    D.) Create custom fields in Rally and TestRail:
    E.) Running the TestRail connector:


A.) Overview:
    01) This connector release consists of the following files:
            - ReadMe.txt
            - gems/
                - activesupport-4.1.7.gem
                - httpclient-2.4.0.gem
                - i18n-0.6.11.gem
                - mime-types-2.0.gem
                - mini_portile-0.6.0.gem
                - minitest-5.4.3.gem
                - multipart-post-1.2.0.gem
                - nokogiri-1.6.4.1-x86-mingw32.gem
                - nokogiri-1.6.4.1.gem-MacOS
                - rally_api-1.1.2.gem
                - rallyeif-testrail-4.0.0.gem
                - rallyeif-wrk-0.5.5.gem
                - thread_safe-0.3.4.gem
                - tzinfo-1.2.2.gem
                - uninstall_all.txt
                - xml-simple-1.1.2.gem
                - rally2_testrail_connector.rb
            - test_connections.xml
            - testrail-api-master/
                - license.md
                - readme.md
                - ruby/
                    - readme.md
                    - testrail.rb
            - WinTail.exe

    02) This connnector was tested on Ruby version 2.0.0-p643,
        on a AWS Windows Server 2012 R2 (64-bit) using PowerShell.

    03) This connector code was developed on MAC-OS (OS X Yosemite - 10.10).
    

B.) Installation of Ruby:
    01) Be sure Ruby is installed:
            - Command:
                > ruby -v
            - Output:
                ruby 2.0.0p643 (2015-02-25) [i386-mingw32]


    02) If Ruby is not installed, do it via:
            - Get Ruby installer here:  http://dl.bintray.com/oneclick/rubyinstaller/
                - Get this one:  rubyinstaller-2.0.0-p643.exe
                - Invoke the above installer and select an install location:
                    - Something like "C:\Ruby200-p643"
                - Select all 3 install options:
                    - Install Td/Tk support
                    - Add Ruby executables to your PATH
                    - Associate .rb and .rbw files with this Ruby installation
                - When done, verify the install in a *newly opened* MS-DOS window:
                    - Command:
                        > ruby -v
                    - Output:
                        ruby 2.0.0p643 (2015-02-25) [i386-mingw32]


    03) When done, the default installed GEMs are:
            - Command:
                > gem list
            - Output:

                *** LOCAL GEMS ***

                bigdecimal (1.2.0)
                io-console (0.4.2)
                json (1.7.7)
                minitest (4.3.2)
                psych (2.0.0)
                rake (0.9.6)
                rdoc (4.0.0)
                test-unit (2.0.0.0)


C.) Installation of the TestRail connector GEMs:
    01) Extract the ZIP file provided into a work area (like your home folder):
            - Command:
                > unzip reldir-01.zip 
            - Output:
                Archive:  reldir-01.zip
                   creating: reldir-01/
				   creating: reldir-01/gems/
				  inflating: reldir-01/gems/activesupport-4.1.7.gem  
				  inflating: reldir-01/gems/httpclient-2.4.0.gem  
				  inflating: reldir-01/gems/i18n-0.6.11.gem  
				  inflating: reldir-01/gems/mime-types-2.0.gem  
				  inflating: reldir-01/gems/mini_portile-0.6.0.gem  
				  inflating: reldir-01/gems/minitest-5.4.3.gem  
				  inflating: reldir-01/gems/multipart-post-1.2.0.gem  
				  inflating: reldir-01/gems/nokogiri-1.6.4.1-x86-mingw32.gem  
				  inflating: reldir-01/gems/nokogiri-1.6.4.1.gem-MacOS
				  inflating: reldir-01/gems/rally_api-1.1.2.gem  
				  inflating: reldir-01/gems/rallyeif-testrail-4.0.0.gem  
				  inflating: reldir-01/gems/rallyeif-wrk-0.5.5.gem  
				  inflating: reldir-01/gems/thread_safe-0.3.4.gem  
				  inflating: reldir-01/gems/tzinfo-1.2.2.gem  
				  inflating: reldir-01/gems/uninstall_all.txt  
				  inflating: reldir-01/gems/xml-simple-1.1.2.gem  
				  inflating: reldir-01/rally2_testrail_connector.rb  
				  inflating: reldir-01/ReadMe.txt    
				  inflating: reldir-01/test-connection.xml  
				   creating: reldir-01/testrail-api-master/
				  inflating: reldir-01/testrail-api-master/license.md  
				  inflating: reldir-01/testrail-api-master/readme.md  
				   creating: reldir-01/testrail-api-master/ruby/
				  inflating: reldir-01/testrail-api-master/ruby/readme.md  
				  inflating: reldir-01/testrail-api-master/ruby/testrail.rb  
				  inflating: reldir-01/WinTail.exe


    02) Install the GEMs provided with the new Salesforce connector:
            - Command:
                > cd reldir-01\gems
                > gem install --local *.gem
                > cd ..
            - Output:
				Successfully installed i18n-0.6.11
				Successfully installed thread_safe-0.3.4
				Successfully installed tzinfo-1.2.2
				Successfully installed activesupport-4.1.7
				Parsing documentation for i18n-0.6.11
				Installing ri documentation for i18n-0.6.11
				Parsing documentation for thread_safe-0.3.4
				Installing ri documentation for thread_safe-0.3.4
				Parsing documentation for tzinfo-1.2.2
				Installing ri documentation for tzinfo-1.2.2
				Parsing documentation for activesupport-4.1.7
				unable to convert "\x80" from ASCII-8BIT to UTF-8 for lib/active_support/values/unicode_tables.dat, skipping
				Installing ri documentation for activesupport-4.1.7
				Successfully installed httpclient-2.4.0
				Parsing documentation for httpclient-2.4.0
				Installing ri documentation for httpclient-2.4.0
				Successfully installed i18n-0.6.11
				Parsing documentation for i18n-0.6.11
				Successfully installed mime-types-2.0
				Parsing documentation for mime-types-2.0
				Installing ri documentation for mime-types-2.0
				Successfully installed minitest-5.4.3
				Parsing documentation for minitest-5.4.3
				Successfully installed mini_portile-0.6.0
				Parsing documentation for mini_portile-0.6.0
				Installing ri documentation for mini_portile-0.6.0
				Successfully installed multipart-post-1.2.0
				Parsing documentation for multipart-post-1.2.0
				Installing ri documentation for multipart-post-1.2.0
				Nokogiri is built with the packaged libraries: libxml2-2.9.2, libxslt-1.1.28, zlib-1.2.8, libiconv-1.14.
				Successfully installed nokogiri-1.6.4.1-x86-mingw32
				Parsing documentation for nokogiri-1.6.4.1-x86-mingw32
				unable to convert "\x90" from ASCII-8BIT to UTF-8 for lib/nokogiri/1.9/nokogiri.so, skipping
				unable to convert "\x90" from ASCII-8BIT to UTF-8 for lib/nokogiri/2.0/nokogiri.so, skipping
				unable to convert "\x90" from ASCII-8BIT to UTF-8 for lib/nokogiri/2.1/nokogiri.so, skipping
				Installing ri documentation for nokogiri-1.6.4.1-x86-mingw32
				Successfully installed rally_api-1.1.2
				Successfully installed rallyeif-wrk-0.5.5
				Successfully installed rallyeif-testrail-4.0.0
				Parsing documentation for rally_api-1.1.2
				Installing ri documentation for rally_api-1.1.2
				Parsing documentation for rallyeif-wrk-0.5.5
				Installing ri documentation for rallyeif-wrk-0.5.5
				Parsing documentation for rallyeif-testrail-4.0.0
				Installing ri documentation for rallyeif-testrail-4.0.0
				Successfully installed rallyeif-wrk-0.5.5
				Parsing documentation for rallyeif-wrk-0.5.5
				Successfully installed rally_api-1.1.2
				Parsing documentation for rally_api-1.1.2
				Successfully installed thread_safe-0.3.4
				Parsing documentation for thread_safe-0.3.4
				Successfully installed tzinfo-1.2.2
				Parsing documentation for tzinfo-1.2.2
				Successfully installed xml-simple-1.1.2
				Parsing documentation for xml-simple-1.1.2
				Installing ri documentation for xml-simple-1.1.2
				19 gems installed

    03) When done, the installed GEMs are:
            - Command:
                > gem list
            - Output:
                
                *** LOCAL GEMS ***
                
                activesupport (4.1.7)
                bigdecimal (1.2.0)
                httpclient (2.4.0)
                i18n (0.6.11)
                io-console (0.4.2)
                json (1.7.7)
                mime-types (2.0)
                mini_portile (0.6.0)
                minitest (5.4.3, 4.3.2)
                multipart-post (1.2.0)
                nokogiri (1.6.4.1 x86-mingw32)
                psych (2.0.0)
                rake (0.9.6)
                rally_api (1.1.2)
                rallyeif-testrail (4.0.0)
                rallyeif-wrk (0.5.5)
                rdoc (4.0.0)
                test-unit (2.0.0.0)
                thread_safe (0.3.4)
                tzinfo (1.2.2)
                xml-simple (1.1.2)


    04) Verify the connector was installed:
            - Commands:
                > cd reldir-01
                > rally2_testrail_connector.rb  --version
            - Output:
                DL is deprecated, please use Fiddle
                Work Item Connector Hub version 0.5.5-ts3pm2
                Rally Spoke version 4.4.10 using rally_api gem version 1.1.2
                TestRailConnection version 4.0.0-ts1


D.) Create custom fields in Rally and TestRail:
    01) The following Rally custom field is used by the connector:
        Object     Name                 Display Name      Type
        ---------  -------------------  --------------    -------     --------
        Test Case  TestRailID           TestRailID        String      Required

    02) The following TestRail custom fields are used by the connector:
        Object     Label                System Name       Type
        ---------  -------------------  --------------    ----------  --------
        Test Case  RallyObjectID        rallyobjectid     Integer     Required
        Test Case  RallyFormattedID     rallyformattedid  String      Optional
        Test Case  RallyURL             rallyurl          Url (Link)  Optional


E.) Running the TestRail connector:
    01) Edit a configuration file (such as "test_connections.xml" provided) and 
        adjust it for your environment.

    02) Run the connector:
            - Command:
                > rally2_testrail_connector.rb  test_connections.xml  -1
            - Output:
                The output will be in the file "rallylog.log".


[the end]
