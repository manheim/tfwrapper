# frozen_string_literal: true

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
    'linux'
  end

  def bin_arch
    'amd64'
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
    return true
  end

  def fetch
    return bin_path unless vendored_required?
    require 'open-uri'

    puts "Fetching #{package_url}..."

    zippath = "vendor/#{program}.zip"
    begin
      File.open(zippath, "wb") do |saved_file|
        open(package_url, "rb") do |read_file|
          saved_file.write(read_file.read)
        end
      end
    rescue OpenURI::HTTPError
      puts "#{@prog_cap} version #{@version} not found (HTTPError for " \
        "#{package_url})."
      break
    end

    puts "Extracting binary #{bin_dir}..."
    system 'mkdir', '-p', bin_dir
    system 'unzip', zippath, '-d', bin_dir

    puts "Cleaning up..."
    system 'rm', zippath
    fail unless is_correct_version?
    bin_path
  end

  def is_correct_version?
    ver = `#{bin_path} -version`.strip
    unless ver =~ /^#{Regexp.quote(@prog_cap)} v#{Regexp.quote(@version)}/
      puts "ERROR: Tests need #{@prog_cap} version #{@version} but got: #{ver}"
      return false
    end
    true
  end
end
