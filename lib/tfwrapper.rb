# TFWrapper module
module TFWrapper
end

gem_libs_dir = "#{File.dirname File.absolute_path(__FILE__)}/tfwrapper"
Dir.glob("#{gem_libs_dir}/*.rb") { |file| require file }
