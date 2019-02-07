# frozen_string_literal: true

require 'ffi'
require 'faraday'
require 'json'
require 'retries'

def fixture_dir
  File.absolute_path(
    File.join(File.dirname(__FILE__), '..', 'fixtures')
  )
end

def cleanup_tf
  Dir.glob("#{fixture_dir}/**/.terraform").each do |d|
    FileUtils.rmtree(d) if File.directory?(d)
  end
  Dir.glob("#{fixture_dir}/**/terraform.tfstate*").each do |f|
    File.delete(f)
  end
end

def desired_tf_version
  if ENV.include?('TF_VERSION') && ENV['TF_VERSION'] != 'latest'
    return ENV['TF_VERSION']
  end
  # else get the latest release from GitHub
  latest_tf_version
end

def latest_tf_version
  resp = Faraday.get('https://checkpoint-api.hashicorp.com/v1/check/terraform')
  rel = JSON.parse(resp.body)['current_version']
  puts "Found latest terraform release as: #{rel}"
  rel
end

# Given the example terraform plan output with placeholders for the
# latest terraform version and fixtures path, return the interpolated string.
def clean_tf_plan_output(raw_out, latest_ver, fixture_path)
  raw_out
    .gsub('%%TF_LATEST_VER%%', latest_ver)
    .gsub('%%FIXTUREPATH%%', fixture_path)
end

class HashicorpFetcher
  def initialize(program, version)
    @program = program
    @prog_ucase = @program.upcase
    @prog_cap = @program.capitalize
    @version = version
  end

  def bin_dir
    "vendor/bin/#{@program}/#{@version}"
  end

  def bin_os
    FFI::Platform::OS
  end

  def bin_arch
    arch = FFI::Platform::ARCH
    case arch
    when /x86_64|amd64/
      'amd64'
    when /i?86|x86/
      '386'
    else
      arch
    end
  end

  def bin_path
    return ENV["#{@prog_ucase}_BIN"] if ENV.include?("#{@prog_ucase}_BIN")
    "#{bin_dir}/#{@program}"
  end

  def package_name
    "#{@program}_#{@version}_#{bin_os}_#{bin_arch}.zip"
  end

  def package_url
    "https://releases.hashicorp.com/#{@program}/#{@version}/#{package_name}"
  end

  def vendored_required?
    return false if File.file?(bin_path) && is_correct_version?
    true
  end

  def fetch
    return File.realpath(bin_path) unless vendored_required?
    require 'open-uri'

    puts "Fetching #{package_url}..."

    zippath = "vendor/#{@program}.zip"
    Dir.mkdir('vendor') unless File.directory?('vendor')
    begin
      File.open(zippath, 'wb') do |saved_file|
        open(package_url, 'rb') do |read_file|
          saved_file.write(read_file.read)
        end
      end
    rescue OpenURI::HTTPError
      raise StandardError, "#{@prog_cap} version #{@version} not found " \
        "(HTTPError for #{package_url})."
    end

    puts "Extracting binary #{bin_dir}..."
    system 'mkdir', '-p', bin_dir
    system 'unzip', zippath, '-d', bin_dir

    puts 'Cleaning up...'
    system 'rm', zippath
    raise StandardErrro, 'Error: wrong version' unless is_correct_version?
    File.realpath(bin_path)
  end

  def is_correct_version?
    ver = `#{bin_path} version`.strip
    unless ver =~ /^#{Regexp.quote(@prog_cap)} v#{Regexp.quote(@version)}/
      puts "ERROR: Tests need #{@prog_cap} version #{@version} but got: #{ver}"
      return false
    end
    true
  end
end
