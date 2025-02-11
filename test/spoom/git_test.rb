# typed: true
# frozen_string_literal: true

require "test_with_project"

module Spoom
  module Git
    class GitTest < TestWithProject
      def setup
        @project.git_init!
        @project.exec("git config user.name 'spoom-tests'")
        @project.exec("git config user.email 'spoom@shopify.com'")
      end

      def test_exec_with_unexisting_path
        result = Spoom::Git.exec("git ls", path: "/path/not/found")
        assert_equal("Error: `/path/not/found` is not a directory.", result.err)
        refute(result.status)
      end

      def test_last_commit_if_not_git_dir
        @project.remove!(".git")
        assert(Spoom::Git.last_commit(path: @project.absolute_path).nil?)
      end

      def test_last_commit_if_no_commit
        assert(Spoom::Git.last_commit(path: @project.absolute_path).nil?)
      end

      def test_last_commit
        @project.write!("file")
        @project.commit!
        assert(Spoom::Git.last_commit(path: @project.absolute_path))
      end

      def test_clean_workdir_on_clean_repo
        @project.write!("file")
        @project.commit!
        assert(Spoom::Git.workdir_clean?(path: @project.absolute_path))
      end

      def test_clean_workdir_on_dirty_repo
        @project.write!("file", "content1")
        @project.commit!
        @project.write!("file", "content2")
        refute(Spoom::Git.workdir_clean?(path: @project.absolute_path))
      end

      def test_commit_timestamp
        date = Time.parse("1987-02-05 09:00:00")
        @project.write!("file")
        @project.commit!(date: date)
        sha = Spoom::Git.last_commit(path: @project.absolute_path)
        assert_equal(date.strftime("%s").to_i, Spoom::Git.commit_timestamp(T.must(sha), path: @project.absolute_path))
      end

      def test_commit_time
        date = Time.parse("1987-02-05 09:00:00")
        @project.write!("file")
        @project.commit!(date: date)
        sha = Spoom::Git.last_commit(path: @project.absolute_path)
        assert_equal(date, Spoom::Git.commit_time(T.must(sha), path: @project.absolute_path))
      end

      def test_git_diff
        assert_equal("", Spoom::Git.diff("HEAD", path: @project.absolute_path).out)
        @project.write!("file", "content")
        assert_equal("", Spoom::Git.diff("HEAD", path: @project.absolute_path).out)
        @project.commit!
        assert_equal("", Spoom::Git.diff("HEAD", path: @project.absolute_path).out)
        @project.write!("file", "content2")
        assert_match(/content2/, Spoom::Git.diff("HEAD", path: @project.absolute_path).out)
        @project.commit!
        assert_equal("", Spoom::Git.diff("HEAD", path: @project.absolute_path).out)
      end

      def test_git_log
        @project.write!("file")
        @project.commit!(date: Time.parse("1987-02-05 09:00:00 +0000"))
        log = Spoom::Git.log("--format='format:%ad'", path: @project.absolute_path).out
        assert_equal("Thu Feb 5 09:00:00 1987 +0000", log)
      end

      def test_git_rev_parse
        @project.write!("file")
        @project.commit!
        assert_match(/^[a-f0-9]+$/, Spoom::Git.rev_parse("main", path: @project.absolute_path).out.strip)
      end

      def test_git_show
        @project.write!("file")
        @project.commit!(date: Time.parse("1987-02-05 09:00:00"))
        assert_match(/Thu Feb 5 09:00:00 1987/, Spoom::Git.show(path: @project.absolute_path).out)
      end

      def test_sorbet_intro_not_found
        sha = Spoom::Git.sorbet_intro_commit(path: @project.absolute_path)
        assert_nil(sha)
      end

      def test_sorbet_intro_found
        @project.write!("sorbet/config")
        @project.commit!
        sha = Spoom::Git.sorbet_intro_commit(path: @project.absolute_path)
        assert_match(/\A[a-z0-9]+\z/, sha)
      end

      def test_sorbet_removal_not_found
        sha = Spoom::Git.sorbet_removal_commit(path: @project.absolute_path)
        assert_nil(sha)
      end

      def test_sorbet_removal_found
        @project.write!("sorbet/config")
        @project.commit!
        @project.remove!("sorbet/config")
        @project.commit!
        sha = Spoom::Git.sorbet_removal_commit(path: @project.absolute_path)
        assert_match(/\A[a-z0-9]+\z/, sha)
      end
    end
  end
end
