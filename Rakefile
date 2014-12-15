require 'bundler/gem_tasks'
require 'ci/reporter/rake/rspec'
require 'rspec/core/rake_task'
require 'erb'
require 'rubygems/commands/inabox_command'

RSpec::Core::RakeTask.new(:spec)

SPOKE_SOURCE_BASE = "lib/rallyeif/salesforce"

task :default => :spec

desc "substitute in jenkins info"
task :substitute do |t|
  unless (ENV["BUILD_NUMBER"].nil? && ENV["GIT_BRANCH"].nil?)
    Dir.chdir(SPOKE_SOURCE_BASE) do
      content = ''
      version_file = "version.rb"
      File.open(version_file, 'r') {|f| content = f.read}

      @git_branch     = ENV["GIT_BRANCH"]
      @git_commit     = ENV["GIT_COMMIT"]
      @jenkins_build  = ENV["BUILD_NUMBER"]
      content = ERB.new(content).result

      File.open(version_file, 'w') {|f| f.write(content)}
    end
  end
end

desc "publish gem to Rally gem server"
task :publish_gem do
  g = Gem::Commands::InaboxCommand.new
  g.options[:overwrite] = true
  g.options[:host] = "http://int-ububld1:9292/"
  g.options[:args] = []
  g.execute
end

desc "build gem and publish to Rally gem server"
task :publish => [:substitute, :build, :publish_gem]
