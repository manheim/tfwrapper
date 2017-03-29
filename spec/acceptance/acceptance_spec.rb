# frozen_string_literal: true

require 'consulserver'
require 'acceptance_helpers'

describe 'tfwrapper' do
  before(:all) do
    tf_path = File.dirname(HashicorpFetcher.new('terraform', '0.9.0').fetch)
    ENV['PATH'] = "#{tf_path}:#{ENV['PATH']}"
  end
  before(:each) do
    @server = ConsulServer.new
  end
  after(:each) do
    @server.stop
  end
end
