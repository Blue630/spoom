# typed: true
# frozen_string_literal: true

require 'find'
require 'open3'

module Spoom
  module Cli
    class Bump < Thor
      extend T::Sig
      include Helper

      default_task :bump

      desc "bump DIRECTORY", "Change Sorbet sigils from one strictness to another when no errors"
      option :from, type: :string, default: Spoom::Sorbet::Sigils::STRICTNESS_FALSE,
        desc: "Change only files from this strictness"
      option :to, type: :string, default: Spoom::Sorbet::Sigils::STRICTNESS_TRUE,
        desc: "Change files to this strictness"
      option :force, type: :boolean, default: false, aliases: :f,
        desc: "Change strictness without type checking"
      option :sorbet, type: :string, desc: "Path to custom Sorbet bin"
      sig { params(directory: String).void }
      def bump(directory = ".")
        in_sorbet_project!

        from = options[:from]
        to = options[:to]
        force = options[:force]
        exec_path = File.expand_path(self.exec_path)

        unless Sorbet::Sigils.valid_strictness?(from)
          say_error("Invalid strictness #{from} for option --from")
          exit(1)
        end

        unless Sorbet::Sigils.valid_strictness?(to)
          say_error("Invalid strictness #{to} for option --to")
          exit(1)
        end

        directory = File.expand_path(directory)
        files_to_bump = Sorbet::Sigils.files_with_sigil_strictness(directory, from)

        if files_to_bump.empty?
          $stderr.puts("No file to bump from #{from} to #{to}")
          exit(0)
        end

        Sorbet::Sigils.change_sigil_in_files(files_to_bump, to)

        if force
          print_changes(files_to_bump, from: from, to: to, path: exec_path)
          exit(0)
        end

        output, no_errors = Sorbet.srb_tc(path: exec_path, capture_err: true, sorbet_bin: options[:sorbet])

        if no_errors
          print_changes(files_to_bump, from: from, to: to, path: exec_path)
          exit(0)
        end

        errors = Sorbet::Errors::Parser.parse_string(output)

        files_with_errors = errors.map do |err|
          path = File.expand_path(err.file)
          next unless path.start_with?(directory)
          next unless File.file?(path)
          path
        end.compact.uniq

        Sorbet::Sigils.change_sigil_in_files(files_with_errors, from)

        files_changed = files_to_bump - files_with_errors
        print_changes(files_changed, from: from, to: to, path: exec_path)
      end

      no_commands do
        def print_changes(files, from: "false", to: "true", path: File.expand_path("."))
          if files.empty?
            $stderr.puts("No file to bump from #{from} to #{to}")
            return
          end
          $stderr.puts("Bumped #{files.size} file#{'s' if files.size > 1} from #{from} to #{to}:")
          files.each do |file|
            file_path = Pathname.new(file).relative_path_from(path)
            $stderr.puts(" + #{file_path}")
          end
        end
      end
    end
  end
end
