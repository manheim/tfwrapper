# frozen_string_literal: true

require 'simplecov'
require 'simplecov-console'
require 'rspec_junit_formatter'

# for naming coverage and test results in CircleCI by ruby version tested
dir_suffix = ''
if ENV['GEM_HOME']
  ver = File.basename(ENV['GEM_HOME'])
  dir_suffix = "-#{ver}"
end

# for storing artifacts in the right place for CircleCI
if ENV['CIRCLE_ARTIFACTS']
  dir = File.join(ENV['CIRCLE_ARTIFACTS'], "coverage#{dir_suffix}")
  SimpleCov.coverage_dir(dir)
end

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new(
  [SimpleCov::Formatter::HTMLFormatter, SimpleCov::Formatter::Console]
)

SimpleCov.start do
  add_filter '/vendor/'
  add_filter '/spec/'
end

$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)

RSpec.configure do |config|
  # moved from .rspec to interpolate $CIRCLE_ARTIFACTS as output directory
  # see: https://circleci.com/docs/build-artifacts and
  # http://blog.circleci.com/build-artifacts/
  # and also use CircleCI Junit parsing:
  # http://blog.circleci.com/announcing-detailed-test-failure-reporting/
  if ENV.key?('CIRCLE_ARTIFACTS')
    junit_results_path = "#{ENV['CIRCLE_TEST_REPORTS']}/rspec/results"\
      "#{dir_suffix}.xml"
    html_results_path = "#{ENV['CIRCLE_TEST_REPORTS']}/rspec/results"\
      "#{dir_suffix}.html"
  else
    junit_results_path = 'results/results.xml'
    html_results_path = 'results/results.html'
  end
  config.color = true
  config.order = :random
  # documentation format
  config.add_formatter(:documentation)
  # HTML format
  # @see https://github.com/rspec/rspec-core/blob/v2.14.8/lib/rspec/core/configuration.rb#L1086
  config.add_formatter(:html, html_results_path)
  # JUnit results
  config.add_formatter('RspecJunitFormatter', junit_results_path)
end
