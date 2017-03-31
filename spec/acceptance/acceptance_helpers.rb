# frozen_string_literal: true

require 'ffi'

def cleanup_tf
  fixture_dir = File.absolute_path(
    File.join(File.dirname(__FILE__), '..', 'fixtures')
  )
  Dir.glob("#{fixture_dir}/**/.terraform").each do |d|
    FileUtils.rmtree(d) if File.directory?(d)
  end
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

  # rubocop:disable Metrics/AbcSize
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
  # rubocop:enable Metrics/AbcSize

  def is_correct_version?
    ver = `#{bin_path} version`.strip
    unless ver =~ /^#{Regexp.quote(@prog_cap)} v#{Regexp.quote(@version)}/
      puts "ERROR: Tests need #{@prog_cap} version #{@version} but got: #{ver}"
      return false
    end
    true
  end
end
