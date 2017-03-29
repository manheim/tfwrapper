# frozen_string_literal: true

require 'acceptance_helpers'

# Run a Consul server process in the background, for acceptance tests
class ConsulServer

  def initialize(version='0.7.5')
    bin_path = HashicorpFetcher.new('consul', version).fetch
    @process = Process.spawn("#{bin_path} server -dev")
  end

  def stop
    return if @process.nil?
    Process.kill('TERM', @process)
    Process.wait
  end

end
