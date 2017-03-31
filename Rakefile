# frozen_string_literal: true

require 'rubygems'
require 'bundler'
require 'bundler/setup'
require 'bundler/gem_tasks'
require 'rake/clean'
require 'yard'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

CLOBBER.include 'pkg'

desc 'Run RuboCop on the lib directory'
RuboCop::RakeTask.new(:rubocop) do |task|
  task.fail_on_error = true
end

namespace :spec do
  desc 'run ALL spec tests'
  task all: %i(unit acceptance)

  desc 'run unit tests'
  RSpec::Core::RakeTask.new(:unit) do |t|
    t.rspec_opts = ['--require', 'spec_helper']
    t.pattern = 'spec/unit/*_spec.rb'
  end

  desc 'run acceptance tests'
  RSpec::Core::RakeTask.new(:acceptance) do |t|
    t.rspec_opts = ['--require', 'spec_helper']
    t.pattern = 'spec/acceptance/*_spec.rb'
  end
end

namespace :yard do
  YARD::Rake::YardocTask.new do |t|
    t.name = 'generate'
    t.files   = ['lib/**/*.rb'] # optional
    t.options = ['--private', '--protected'] # optional
    t.stats_options = ['--list-undoc'] # optional
  end

  desc 'serve YARD documentation on port 8808 (restart to regenerate)'
  task serve: [:generate] do
    puts 'Running YARD server on port 8808'
    puts 'Use Ctrl+C to exit server.'
    YARD::CLI::Server.run
  end
end

desc 'Run specs and rubocop before pushing'
task pre_commit: %i(spec:unit rubocop)

desc 'Display the list of available rake tasks'
task :help do
  system('rake -T')
end

task default: [:help]
