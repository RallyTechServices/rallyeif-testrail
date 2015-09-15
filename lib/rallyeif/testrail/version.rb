# Copyright 2001-2014 Rally Software Development Corp. All Rights Reserved.
module RallyEIF
  module TestRail
    module Version

      VERSION = "4.0.0"

      def self.to_s
        VERSION.to_s
      end

      GIT_BRANCH   = "<%= @git_branch %>" unless defined? GIT_BRANCH
      GIT_COMMIT   = "<%= @git_commit %>" unless defined? GIT_COMMIT
      BUILD_NUMBER = "<%= @jenkins_build %>" unless defined? BUILD_NUMBER

      def self.detail
        "ts12"
      end

    end
  end
end
