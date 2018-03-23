# frozen_string_literal: true

require 'tfwrapper/helpers'
require 'json'
require 'rake'
require 'rubygems'
require 'tfwrapper/version'

# :nocov:
begin
  require 'terraform_landscape'
  HAVE_LANDSCAPE = true
rescue LoadError
  HAVE_LANDSCAPE = false
end
# :nocov:

module TFWrapper
  # Generates Rake tasks for working with Terraform.
  class RakeTasks
    include Rake::DSL if defined? Rake::DSL

    class << self
      # set when installed
      attr_accessor :instance

      # Install the Rake tasks for working with Terraform. For full parameter
      # documentation, see {TFWrapper::RakeTasks#initialize}
      #
      # @param (see #initialize)
      def install_tasks(tf_dir, opts = {})
        new(tf_dir, opts).install
      end
    end

    def min_tf_version
      Gem::Version.new('0.9.0')
    end

    attr_reader :tf_version

    # Generate Rake tasks for working with Terraform.
    #
    # @param tf_dir [String] Terraform config directory, relative to Rakefile.
    #   Set to '.' if the Rakefile is in the same directory as the ``.tf``
    #   configuration files.
    # @option opts [Hash] :backend_config hash of Terraform remote state
    #   backend configuration options, to override or supplement those in
    #   the terraform configuration. See the
    #   [Remote State](https://www.terraform.io/docs/state/remote.html)
    #   documentation for further information.
    # @option opts [String] :namespace_prefix if specified and not nil, this
    #   will put all tasks in a "#{namespace_prefix}_tf:" namespace instead
    #   of "tf:". This allows using manheim_helpers for multiple terraform
    #   configurations in the same Rakefile.
    # @option opts [Hash] :tf_vars_from_env hash of Terraform variables to the
    #   (required) environment variables to populate their values from
    # @option opts [Hash] :tf_extra_vars hash of Terraform variables to their
    #   values; overrides any same-named keys in ``tf_vars_from_env``
    # @option opts [String] :consul_url URL to access Consul at, for the
    #   ``:consul_env_vars_prefix`` option.
    # @option opts [String] :consul_env_vars_prefix if specified and not nil,
    #   write the environment variables used from ``tf_vars_from_env``
    #   and their values to JSON at this path in Consul. This should have
    #   the same naming constraints as ``consul_prefix``.
    # @option opts [Proc] :before_proc Proc instance to call before executing
    #   the body of each task. Called with two arguments, the String full
    #   (namespaced) name of the task being executed, and ``tf_dir``. Returning
    #   or breaking from this Proc will cause the task to not execute; to exit
    #   the Proc early, use ``next``.
    # @option opts [Proc] :after_proc Proc instance to call after executing
    #   the body of each task. Called with two arguments, the String full
    #   (namespaced) name of the task being executed, and ``tf_dir``. This will
    #   not execute if the body of the task fails.
    # @option opts [Bool] :disable_landscape By default, if the
    #  ``terraform_landscape`` gem can be loaded, it will be used to reformat
    #  the output of ``terraform plan``. If this is not desired, set to
    #  ``true`` to disable landscale. Default: ``false``.
    # @option opts [Symbol, nil] :landscape_progress The ``terraform_landscape``
    #  code used to reformat plan output requires the full output of the
    #  complete ``plan`` execution. By default, this means that when landscape
    #  is used, no output will appear from the time ``terraform plan`` begins
    #  until the command is complete. If progress output is desired, this option
    #  can be set to one of the following: ``:dots`` to print a dot to STDOUT
    #  for every line of ``terraform plan`` output, ``:lines`` to print a dot
    #  followed by a newline (e.g. for systems like Jenkins that line buffer)
    #  for every line of ``terraform plan`` output, or ``:stream`` to stream
    #  the raw ``terraform plan`` output (which will then be followed by the
    #  reformatted landscape output). Default is ``nil`` to show no progress
    #  output.
    def initialize(tf_dir, opts = {})
      # find the directory that contains the Rakefile
      rakedir = File.realpath(Rake.application.rakefile)
      rakedir = File.dirname(rakedir) if File.file?(rakedir)
      @tf_dir = File.realpath(File.join(rakedir, tf_dir))
      @ns_prefix = opts.fetch(:namespace_prefix, nil)
      @consul_env_vars_prefix = opts.fetch(:consul_env_vars_prefix, nil)
      @tf_vars_from_env = opts.fetch(:tf_vars_from_env, {})
      @tf_extra_vars = opts.fetch(:tf_extra_vars, {})
      @backend_config = opts.fetch(:backend_config, {})
      @consul_url = opts.fetch(:consul_url, nil)
      @disable_landscape = opts.fetch(:disable_landscape, false)
      @landscape_progress = opts.fetch(:landscape_progress, nil)
      unless [:dots, :lines, :stream, nil].include?(@landscape_progress)
        raise(
          ArgumentError,
          'landscape_progress option must be one of: ' \
          '[:dots, :lines, :stream, nil]'
        )
      end
      @before_proc = opts.fetch(:before_proc, nil)
      if !@before_proc.nil? && !@before_proc.is_a?(Proc)
        raise(
          TypeError,
          'TFWrapper::RakeTasks.initialize option :before_proc must be a ' \
          'Proc instance, not a ' + @before_proc.class.name
        )
      end
      @after_proc = opts.fetch(:after_proc, nil)
      if !@after_proc.nil? && !@after_proc.is_a?(Proc)
        raise(
          TypeError,
          'TFWrapper::RakeTasks.initialize option :after_proc must be a Proc ' \
          'instance, not a ' + @after_proc.class.name
        )
      end
      # default to lowest possible version; this is set in the 'init' task
      @tf_version = Gem::Version.new('0.0.0')
      # rubocop:disable Style/GuardClause
      if @consul_url.nil? && !@consul_env_vars_prefix.nil?
        raise StandardError, 'Cannot set env vars in Consul when consul_url ' \
          'option is nil.'
      end
      # rubocop:enable Style/GuardClause
    end

    def nsprefix
      if @ns_prefix.nil?
        'tf'.to_sym
      else
        "#{@ns_prefix}_tf".to_sym
      end
    end

    # install all Rake tasks - calls other install_* methods
    # rubocop:disable Metrics/CyclomaticComplexity
    def install
      install_init
      install_plan
      install_apply
      install_refresh
      install_destroy
      install_write_tf_vars
      install_output
    end

    # add the 'tf:init' Rake task. This checks environment variables,
    # runs ``terraform -version``, and then runs ``terraform init`` with
    # the ``backend_config`` options, if any.
    def install_init
      namespace nsprefix do
        desc 'Run terraform init with appropriate arguments'
        task :init do |t|
          @before_proc.call(t.name, @tf_dir) unless @before_proc.nil?
          TFWrapper::Helpers.check_env_vars(@tf_vars_from_env.values)
          @tf_version = check_tf_version
          cmd = [
            'terraform',
            'init',
            '-input=false'
          ].join(' ')
          @backend_config.each do |k, v|
            cmd = cmd + ' ' + "-backend-config='#{k}=#{v}'"
          end
          terraform_runner(cmd)
          @after_proc.call(t.name, @tf_dir) unless @after_proc.nil?
        end
      end
    end

    # add the 'tf:plan' Rake task
    def install_plan
      namespace nsprefix do
        desc 'Output the set plan to be executed by apply; specify ' \
          'optional CSV targets'
        task :plan, [:target] => [
          :"#{nsprefix}:init",
          :"#{nsprefix}:write_tf_vars"
        ] do |t, args|
          @before_proc.call(t.name, @tf_dir) unless @before_proc.nil?
          cmd = cmd_with_targets(
            ['terraform', 'plan', "-var-file #{var_file_path}"],
            args[:target],
            args.extras
          )

          stream_type = if HAVE_LANDSCAPE && !@disable_landscape
                          @landscape_progress
                        else
                          :stream
                        end
          outerr = terraform_runner(cmd, progress: stream_type)
          landscape_format(outerr) if HAVE_LANDSCAPE && !@disable_landscape
          @after_proc.call(t.name, @tf_dir) unless @after_proc.nil?
        end
      end
    end

    # add the 'tf:apply' Rake task
    def install_apply
      namespace nsprefix do
        desc 'Apply a terraform plan that will provision your resources; ' \
          'specify optional CSV targets'
        task :apply, [:target] => [
          :"#{nsprefix}:init",
          :"#{nsprefix}:write_tf_vars",
          :"#{nsprefix}:plan"
        ] do |t, args|
          @before_proc.call(t.name, @tf_dir) unless @before_proc.nil?
          cmd_arr = %w[terraform apply]
          cmd_arr << '-auto-approve' if tf_version >= Gem::Version.new('0.10.0')
          cmd_arr << "-var-file #{var_file_path}"
          cmd = cmd_with_targets(
            cmd_arr,
            args[:target],
            args.extras
          )
          terraform_runner(cmd)

          update_consul_stack_env_vars unless @consul_env_vars_prefix.nil?
          @after_proc.call(t.name, @tf_dir) unless @after_proc.nil?
        end
      end
    end

    # add the 'tf:refresh' Rake task
    def install_refresh
      namespace nsprefix do
        task refresh: [
          :"#{nsprefix}:init",
          :"#{nsprefix}:write_tf_vars"
        ] do |t|
          @before_proc.call(t.name, @tf_dir) unless @before_proc.nil?
          cmd = [
            'terraform',
            'refresh',
            "-var-file #{var_file_path}"
          ].join(' ')

          terraform_runner(cmd)
          @after_proc.call(t.name, @tf_dir) unless @after_proc.nil?
        end
      end
    end

    # add the 'tf:output' Rake task
    def install_output
      namespace nsprefix do
        task output: [
          :"#{nsprefix}:init",
          :"#{nsprefix}:refresh"
        ] do |t|
          @before_proc.call(t.name, @tf_dir) unless @before_proc.nil?
          terraform_runner('terraform output')
          @after_proc.call(t.name, @tf_dir) unless @after_proc.nil?
        end
        task output_json: [
          :"#{nsprefix}:init",
          :"#{nsprefix}:refresh"
        ] do |t|
          @before_proc.call(t.name, @tf_dir) unless @before_proc.nil?
          terraform_runner('terraform output -json')
          @after_proc.call(t.name, @tf_dir) unless @after_proc.nil?
        end
      end
    end

    # add the 'tf:destroy' Rake task
    def install_destroy
      namespace nsprefix do
        desc 'Destroy any live resources that are tracked by your state ' \
          'files; specify optional CSV targets'
        task :destroy, [:target] => [
          :"#{nsprefix}:init",
          :"#{nsprefix}:write_tf_vars"
        ] do |t, args|
          @before_proc.call(t.name, @tf_dir) unless @before_proc.nil?
          cmd = cmd_with_targets(
            ['terraform', 'destroy', '-force', "-var-file #{var_file_path}"],
            args[:target],
            args.extras
          )

          terraform_runner(cmd)
          @after_proc.call(t.name, @tf_dir) unless @after_proc.nil?
        end
      end
    end

    def var_file_path
      if @ns_prefix.nil?
        File.absolute_path('build.tfvars.json')
      else
        File.absolute_path("#{@ns_prefix}_build.tfvars.json")
      end
    end

    # add the 'tf:write_tf_vars' Rake task
    def install_write_tf_vars
      namespace nsprefix do
        desc "Write #{var_file_path}"
        task :write_tf_vars do |t|
          @before_proc.call(t.name, @tf_dir) unless @before_proc.nil?
          tf_vars = terraform_vars
          puts 'Terraform vars:'
          tf_vars.sort.map do |k, v|
            if %w[aws_access_key aws_secret_key].include?(k)
              puts "#{k} => (redacted)"
            else
              puts "#{k} => #{v}"
            end
          end
          File.open(var_file_path, 'w') do |f|
            f.write(tf_vars.to_json)
          end
          STDERR.puts "Terraform vars written to: #{var_file_path}"
          @after_proc.call(t.name, @tf_dir) unless @after_proc.nil?
        end
      end
    end

    def terraform_vars
      res = {}
      @tf_vars_from_env.each { |tfname, envname| res[tfname] = ENV[envname] }
      @tf_extra_vars.each { |name, val| res[name] = val }
      res
    end

    # Given a string of terraform plan output, format it with
    # terraform_landscape and print the result to STDOUT.
    def landscape_format(output)
      p = TerraformLandscape::Printer.new(
        TerraformLandscape::Output.new(STDOUT)
      )
      p.process_string(output)
    rescue StandardError, ScriptError => ex
      STDERR.puts 'Exception calling terraform_landscape to reformat ' \
                  "output: #{ex.class.name}: #{ex}"
      puts output unless @landscape_progress == :stream
    end

    # Run a Terraform command, providing some useful output and handling AWS
    # API rate limiting gracefully. Raises StandardError on failure. The command
    # is run in @tf_dir.
    #
    # @param cmd [String] Terraform command to run
    # @option opts [Hash] :progress How to handle streaming output. Possible
    #  values are ``:stream`` (default) to stream each line in STDOUT/STDERR
    #  to STDOUT, ``:dots`` to print a dot for each line, ``:lines`` to print
    #  a dot followed by a newline for each line, or ``nil`` to not stream any
    #  output at all.
    # @return [String] combined STDOUT and STDERR
    # rubocop:disable Metrics/PerceivedComplexity
    def terraform_runner(cmd, opts = {})
      stream_type = opts.fetch(:progress, :stream)
      unless [:dots, :lines, :stream, nil].include?(stream_type)
        raise(
          ArgumentError,
          'progress option must be one of: [:dots, :lines, :stream, nil]'
        )
      end
      require 'retries'
      STDERR.puts "terraform_runner command: '#{cmd}' (in #{@tf_dir})"
      out_err = nil
      status = nil
      # exponential backoff as long as we're getting 403s
      handler = proc do |exception, attempt_number, total_delay|
        STDERR.puts "terraform_runner failed with #{exception}; retry " \
          "attempt #{attempt_number}; #{total_delay} seconds have passed."
      end
      status = -1
      with_retries(
        max_tries: 5,
        handler: handler,
        base_sleep_seconds: 1.0,
        max_sleep_seconds: 10.0
      ) do
        # this streams STDOUT and STDERR as a combined stream,
        # and also captures them as a combined string
        out_err, status = TFWrapper::Helpers.run_cmd_stream_output(
          cmd, @tf_dir, progress: stream_type
        )
        if status != 0 && out_err.include?('hrottling')
          raise StandardError, 'Terraform hit AWS API rate limiting'
        end
        if status != 0 && out_err.include?('status code: 403')
          raise StandardError, 'Terraform command got 403 error - access ' \
            'denied or credentials not propagated'
        end
        if status != 0 && out_err.include?('status code: 401')
          raise StandardError, 'Terraform command got 401 error - access ' \
            'denied or credentials not propagated'
        end
      end
      # end exponential backoff
      unless status.zero?
        raise StandardError, "Errors have occurred executing: '#{cmd}' " \
          "(exited #{status})"
      end
      STDERR.puts "terraform_runner command '#{cmd}' finished and exited 0"
      out_err
    end
    # rubocop:enable Metrics/PerceivedComplexity

    # Check that the terraform version is compatible
    def check_tf_version
      # run: terraform -version
      all_out_err, exit_status = TFWrapper::Helpers.run_cmd_stream_output(
        'terraform version', @tf_dir
      )
      unless exit_status.zero?
        raise StandardError, "ERROR: 'terraform -version' exited " \
          "#{exit_status}: #{all_out_err}"
      end
      all_out_err = all_out_err.strip
      # Find the terraform version string
      m = /Terraform v(\d+\.\d+\.\d+).*/.match(all_out_err)
      unless m
        raise StandardError, 'ERROR: could not determine terraform version ' \
          "from 'terraform -version' output: #{all_out_err}"
      end
      # the version will be a string like:
      # Terraform v0.9.2
      # or:
      # Terraform v0.9.3-dev (<GIT SHA><+CHANGES>)
      tf_ver = Gem::Version.new(m[1])
      unless tf_ver >= min_tf_version
        raise StandardError, "ERROR: tfwrapper #{TFWrapper::VERSION} is only " \
          "compatible with Terraform >= #{min_tf_version} but your terraform " \
          "binary reports itself as #{m[1]} (#{all_out_err})"
      end
      puts "Running with: #{all_out_err}"
      tf_ver
    end

    # update stack status in Consul
    def update_consul_stack_env_vars
      require 'diplomat'
      require 'json'
      data = {}
      @tf_vars_from_env.each_value { |k| data[k] = ENV[k] }

      Diplomat.configure do |config|
        config.url = @consul_url
      end

      puts "Writing stack information to #{@consul_url} at: "\
        "#{@consul_env_vars_prefix}"
      puts JSON.pretty_generate(data)
      raw = JSON.generate(data)
      Diplomat::Kv.put(@consul_env_vars_prefix, raw)
    end

    # Create a terraform command line with optional targets specified; targets
    # are inserted between cmd_array and suffix_array.
    #
    # This is intended to simplify parsing Rake task arguments and inserting
    # them into the command as targets; to get a Rake task to take a variable
    # number of arguments, we define a first argument (``:target``) which is
    # either a String or nil. Any additional arguments specified end up in
    # ``args.extras``, which is either nil or an Array of additional String
    # arguments.
    #
    # @param cmd_array [Array] array of the beginning parts of the terraform
    #   command; usually something like:
    #   ['terraform', 'ACTION', '-var'file', 'VAR_FILE_PATH']
    # @param target [String] the first target parameter given to the Rake
    #   task, or nil.
    # @param extras [Array] array of additional target parameters given to the
    #   Rake task, or nil.
    def cmd_with_targets(cmd_array, target, extras)
      final_arr = cmd_array
      final_arr.concat(['-target', target]) unless target.nil?
      # rubocop:disable Style/SafeNavigation
      extras.each { |e| final_arr.concat(['-target', e]) } unless extras.nil?
      # rubocop:enable Style/SafeNavigation
      final_arr.join(' ')
    end
  end
end
