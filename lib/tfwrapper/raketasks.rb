# frozen_string_literal: true
require 'tfwrapper/helpers'
require 'json'
require 'rake'

module TFWrapper
  # Generates Rake tasks for working with Terraform at Manheim.
  #
  # Before using this, the ``CONSUL_HOST`` environment variable must be set.
  #
  # __NOTE:__ Be sure to document all tasks in README.md
  class RakeTasks
    include Rake::DSL if defined? Rake::DSL

    class << self
      # set when installed
      attr_accessor :instance

      # Install the Rake tasks for working with Terraform at Manheim.
      #
      # @param (see #initialize)
      def install_tasks(tf_dir, remote_prefix, opts = {})
        new(tf_dir, remote_prefix, opts).install
      end
    end

    # Generate Rake tasks for working with Terraform at Manheim.
    #
    # @param tf_dir [String] TerraForm config directory, relative to Rakefile
    # @param remote_prefix [String] path/key to store the Terraform saved
    #   state in Consul. You __must__ be sure that this will be unique
    #   per environment; it should include environment, application,
    #   component, etc. If you set opts[:remote_backend_name] to something
    #   other than "consul", this value is ignored.
    # @param [Hash] options to use when adding tasks
    # @option opts [String] :namespace_prefix if specified and not nil, this
    #   will put all tasks in a "#{namespace_prefix}_tf:" namespace instead
    #   of "tf:". This allows using manheim_helpers for multiple terraform
    #   configurations in the same Rakefile.
    # @option opts [String] :consul_env_vars_prefix if specified and not nil,
    #   write the environment variables used from ``tf_vars_from_env``
    #   and their values  to JSON at this path in Consul. This should have
    #   the same naming constraints as ``consul_prefix``.
    # @option opts [Hash] :tf_vars_from_env hash of Terraform variables to the
    #   (required) environment variables to populate their values from
    # @option opts [Hash] :tf_extra_vars hash of Terraform variables to their
    #   values; overrides any same-named keys in ``tf_vars_from_env``
    # @option opts [String] :remote_backend_name name of the Terraform remote
    #   state storage backend; defaults to "consul"
    # @option opts [Hash] :backend_config hash of Terraform remote state
    #   backend configuration options
    #   if :remote_backend_name == "consul", this defaults to:
    #     { 'address' => ENV['CONSUL_HOST'],
    #       'path' => @consul_prefix
    #     }
    #   if :remote_backend_name == "s3", this defaults to:
    #     { 'bucket' => 'manheim-re',
    #       'key'   => 'terraform/#{ENV['PROJECT']}/#{ENV['ENVIRONMENT']}' \
    #                      '/consul/terraform.tfstate',
    #       'region' => 'us-east-1'
    #     }
    def initialize(tf_dir, remote_prefix, opts = {})
      @tf_dir = tf_dir
      @remote_prefix = remote_prefix
      @ns_prefix = opts.fetch(:namespace_prefix, nil)
      @consul_env_vars_prefix = opts.fetch(:consul_env_vars_prefix, nil)
      @tf_vars_from_env = opts.fetch(:tf_vars_from_env, {})
      @tf_extra_vars = opts.fetch(:tf_extra_vars, {})
      @backend_name = opts.fetch(:remote_backend_name, 'consul')
      @backend_config = opts.fetch(:backend_config, nil)
      return unless @backend_config.nil?
      if @backend_name == 'consul'
        @backend_config = {
          'address' => ENV['CONSUL_HOST'],
          'path' => @remote_prefix
        }
      elsif @backend_name == 's3'
        @backend_config = {
          'bucket' => 'manheim-re',
          'key'    => "terraform/#{ENV['PROJECT']}/#{ENV['ENVIRONMENT']}" \
                      '/terraform.tfstate',
          'region' => 'us-east-1'
        }
      else
        raise StandardError, 'You must specify opts[:backend_config] ' \
          "when using a remote_backend_name other than 'consul' or 's3'" \
          " (#{@backend_name})"
      end
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
      install_get
      install_set_remote
      install_plan
      install_apply
      install_refresh
      install_destroy
      install_write_tf_vars
    end

    # add the 'tf:get' Rake task
    def install_get
      namespace nsprefix do
        desc 'Download and install modules for the configuration'
        task :get do
          TFWrapper::Helpers.check_env_vars(@tf_vars_from_env.values)
          tf_clean
          # output the terraform version for logging purposes
          terraform_runner('terraform -version')
          terraform_runner("terraform get #{@tf_dir}")
        end
      end
    end

    # add the 'tf:set_remote' Rake task. This uses the backend name from
    # ``@remote_backend_name`` and sets ``-backend-config='k=v'`` for every
    # k, v in ``@backend_config``.
    def install_set_remote
      namespace nsprefix do
        desc 'Configure a remote backend for terraform state files ' \
          '(internal use only)'
        task set_remote: [:"#{nsprefix}:get"] do
          cmd = [
            'terraform',
            'remote',
            'config',
            "-backend=#{@backend_name}"
          ].join(' ')
          @backend_config.each do |k, v|
            cmd = cmd + ' ' + "-backend-config='#{k}=#{v}'"
          end
          terraform_runner(cmd)
        end
      end
    end

    # add the 'tf:plan' Rake task
    def install_plan
      namespace nsprefix do
        desc 'Output the set plan to be executed by apply; specify ' \
          'optional CSV targets'
        task :plan, [:target] => [
          :"#{nsprefix}:set_remote",
          :"#{nsprefix}:write_tf_vars"
        ] do |_t, args|
          cmd = cmd_with_targets(
            ['terraform', 'plan', "-var-file #{var_file_path}"],
            [@tf_dir],
            args[:target],
            args.extras
          )

          terraform_runner(cmd)
        end
      end
    end

    # add the 'tf:apply' Rake task
    def install_apply
      namespace nsprefix do
        desc 'Apply a terraform plan that will provision your resources; ' \
          'specify optional CSV targets'
        task :apply, [:target] => [
          :"#{nsprefix}:set_remote",
          :"#{nsprefix}:write_tf_vars",
          :"#{nsprefix}:plan"
        ] do |_t, args|
          cmd = cmd_with_targets(
            ['terraform', 'apply', "-var-file #{var_file_path}"],
            [@tf_dir],
            args[:target],
            args.extras
          )
          terraform_runner(cmd)

          update_consul_stack_env_vars unless @consul_env_vars_prefix.nil?
        end
      end
    end

    # add the 'tf:refresh' Rake task
    def install_refresh
      namespace nsprefix do
        task refresh: [
          :"#{nsprefix}:set_remote",
          :"#{nsprefix}:write_tf_vars"
        ] do
          cmd = [
            'terraform',
            'refresh',
            "-var-file #{var_file_path}",
            @tf_dir
          ].join(' ')

          terraform_runner(cmd)
        end
      end
    end

    # add the 'tf:destroy' Rake task
    def install_destroy
      namespace nsprefix do
        desc 'Destroy any live resources that are tracked by your state ' \
          'files; specify optional CSV targets'
        task :destroy, [:target] => [
          :"#{nsprefix}:set_remote",
          :"#{nsprefix}:write_tf_vars"
        ] do |_t, args|
          cmd = cmd_with_targets(
            ['terraform', 'destroy', '-force', "-var-file #{var_file_path}"],
            [@tf_dir],
            args[:target],
            args.extras
          )

          terraform_runner(cmd)
        end
      end
    end

    def var_file_path
      if @ns_prefix.nil?
        'build.tfvars.json'
      else
        "#{@ns_prefix}_build.tfvars.json"
      end
    end

    # add the 'tf:write_tf_vars' Rake task
    def install_write_tf_vars
      namespace nsprefix do
        desc "Write ./#{var_file_path}"
        task :write_tf_vars do
          tf_vars = terraform_vars
          puts 'Terraform vars:'
          tf_vars.sort.map do |k, v|
            if k == 'aws_access_key' || k == 'aws_secret_key'
              puts "#{k} => (redacted)"
            else
              puts "#{k} => #{v}"
            end
          end
          File.open(var_file_path, 'w') do |f|
            f.write(tf_vars.to_json)
          end
          STDERR.puts "Terraform vars written to: #{var_file_path}"
        end
      end
    end

    def terraform_vars
      res = {}
      @tf_vars_from_env.each { |tfname, envname| res[tfname] = ENV[envname] }
      @tf_extra_vars.each { |name, val| res[name] = val }
      res
    end

    # Run a Terraform command, providing some useful output and handling AWS
    # API rate limiting gracefully. Raises StandardError on failure.
    #
    # @param cmd [String] Terraform command to run
    # rubocop:disable Metrics/PerceivedComplexity
    def terraform_runner(cmd)
      require 'retries'
      STDERR.puts "terraform_runner command: '#{cmd}'"
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
        out_err, status = TFWrapper::Helpers.run_cmd_stream_output(cmd)
        if status != 0 && out_err.include?('hrottling')
          raise StandardError, 'TerraForm hit AWS API rate limiting'
        end
        if status != 0 && out_err.include?('status code: 403')
          raise StandardError, 'TerraForm command got 403 error - access ' \
            'denied or credentials not propagated'
        end
        if status != 0 && out_err.include?('status code: 401')
          raise StandardError, 'TerraForm command got 401 error - access ' \
            'denied or credentials not propagated'
        end
      end
      # end exponential backoff
      unless status.zero?
        raise StandardError, "Errors have occurred executing: '#{cmd}' " \
          "(exited #{status})"
      end
      STDERR.puts "terraform_runner command '#{cmd}' finished and exited 0"
    end
    # rubocop:enable Metrics/PerceivedComplexity

    # clean any local TF state
    def tf_clean
      require 'fileutils'
      if File.exist?('.terraform')
        puts 'Removing .terraform/'
        FileUtils.rm_rf('.terraform')
      end
      return unless File.exist?("#{@tf_dir}/.terraform")
      puts "Removing #{@tf_dir}/.terraform"
      FileUtils.rm_rf("#{@tf_dir}/.terraform")
    end

    # update stack status in Consul
    def update_consul_stack_env_vars
      require 'diplomat'
      require 'json'
      data = {}
      @tf_vars_from_env.values.each { |k| data[k] = ENV[k] }

      Diplomat.configure do |config|
        config.url = "http://#{ENV['CONSUL_HOST']}"
      end

      puts "Writing stack information to Consul at #{@consul_env_vars_prefix}"
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
    # @param suffix_array [Array] array of the end parts of the terraform
    #   command; usually just the path to the TF config directory
    # @param target [String] the first target parameter given to the Rake
    #   task, or nil.
    # @param extras [Array] array of additional target parameters given to the
    #   Rake task, or nil.
    def cmd_with_targets(cmd_array, suffix_array, target, extras)
      final_arr = cmd_array
      final_arr.concat(['-target', target]) unless target.nil?
      extras&.each do |e|
        final_arr.concat(['-target', e])
      end
      final_arr.concat(suffix_array)
      final_arr.join(' ')
    end
  end
end
