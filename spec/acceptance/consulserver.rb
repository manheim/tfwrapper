# frozen_string_literal: true

require_relative 'acceptance_helpers'
require 'diplomat'
require 'retries'

# Run a Consul server process in the background, for acceptance tests
class ConsulServer
  def initialize(version = '0.7.5')
    bin_path = HashicorpFetcher.new('consul', version).fetch
    @process = Process.spawn(
      "#{bin_path} agent -server -dev",
      out: '/dev/null',
      err: '/dev/null'
    )
    Diplomat.configure do |config|
      config.url = 'http://127.0.0.1:8500'
    end
    with_retries(
      max_tries: 40,
      base_sleep_seconds: 0.25,
      max_sleep_seconds: 0.25,
      rescue: [Faraday::ConnectionFailed, Diplomat::UnknownStatus]
    ) do
      Diplomat::Kv.get('/', keys: true)
    end
  end

  def stop
    return if @process.nil?
    Process.kill('TERM', @process)
    Process.wait
  end
end
