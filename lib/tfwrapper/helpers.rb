# frozen_string_literal: true

require 'open3'
require 'English'

# TFWrapper
module TFWrapper
  # generic helper functions for TFWrapper
  module Helpers
    # Run a system command, print the command before running it. If it exits
    # with a non-zero status, print the exit status and output and then
    # `fail`.
    #
    # @param cmd [String] the command to run
    def self.run_cmd(cmd)
      puts "Running command: #{cmd}"
      out = `#{cmd}`
      status = $CHILD_STATUS.exitstatus
      return if status.zero?
      puts "Command exited #{status}:"
      puts out
      raise StandardError, "ERROR: Command failed: #{cmd}"
    end

    # popen2e wrapper to simultaneously stream command output and capture it.
    #
    # STDOUT and STDERR will be combined to the same stream, and returned as one
    # string. This is because there doesn't seem to be a safe, cross-platform
    # way to both capture and stream STDOUT and STDERR separately that isn't
    # prone to deadlocking if large chunks of data are written to the pipes.
    #
    # @param cmd [String] command to run
    # @param pwd [String] directory/path to run command in
    # @option opts [Hash] :progress How to handle streaming output. Possible
    #  values are ``:stream`` (default) to stream each line in STDOUT/STDERR
    #  to STDOUT, ``:dots`` to print a dot for each line, ``:lines`` to print
    #  a dot followed by a newline for each line, or ``nil`` to not stream any
    #  output at all.
    # @return [Array] - out_err [String], exit code [Fixnum]
    def self.run_cmd_stream_output(cmd, pwd, opts = {})
      stream_type = opts.fetch(:progress, :stream)
      unless [:dots, :lines, :stream, nil].include?(stream_type)
        raise(
          ArgumentError,
          'progress option must be one of: [:dots, :lines, :stream, nil]'
        )
      end
      old_sync = $stdout.sync
      $stdout.sync = true
      all_out_err = ''.dup
      exit_status = nil
      Open3.popen2e(cmd, chdir: pwd) do |stdin, stdout_and_err, wait_thread|
        stdin.close_write
        begin
          while (line = stdout_and_err.gets)
            if stream_type == :stream
              puts line
            elsif stream_type == :dots
              STDOUT.print '.'
            elsif stream_type == :lines
              puts '.'
            end
            all_out_err << line
          end
        rescue IOError => e
          STDERR.puts "IOError: #{e}"
        end
        exit_status = wait_thread.value.exitstatus
      end
      # rubocop:disable Style/RedundantReturn
      $stdout.sync = old_sync
      puts '' if stream_type == :dots
      return all_out_err, exit_status
      # rubocop:enable Style/RedundantReturn
    end

    # Ensure that a given list of environment variables are present and
    # non-empty. Raise StandardError if any aren't.
    #
    # @param required [Array] list of required environment variables
    def self.check_env_vars(required)
      missing = []
      required.each do |name|
        if !ENV.include?(name)
          puts "ERROR: Environment variable '#{name}' must be set."
          missing << name
        elsif ENV[name].to_s.strip.empty?
          puts "ERROR: Environment variable '#{name}' must not be empty."
          missing << name
        end
      end
      # rubocop:disable Style/GuardClause
      unless missing.empty?
        raise StandardError, 'Missing or empty environment variables: ' \
          "#{missing}"
      end
      # rubocop:enable Style/GuardClause
    end
  end
end
