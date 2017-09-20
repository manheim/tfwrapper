# frozen_string_literal: true

require File.expand_path('../lib/tfwrapper/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors     = ['jantman']
  gem.email       = ['jason@jasonantman.com']
  gem.summary     = 'Rake tasks for running Hashicorp Terraform sanely'
  gem.description = [
    'tfwrapper provides Rake tasks for working with Hashicorp Terraform 0.9+,',
    'ensuring proper initialization and passing in variables from the ',
    'environment or Ruby, as well as optionally pushing some information to ',
    'Consul. tfwrapper also attempts to detect and retry failed runs due to ',
    'AWS throttling or access denied errors.'
  ].join(' ')
  gem.homepage    = 'http://github.com/Manheim/tfwrapper'
  gem.license     = 'MIT'

  gem.required_ruby_version = '>= 2.0.0'

  gem.add_runtime_dependency 'retries', '~> 0.0.5'

  # awful, but these are to allow use with ruby 2.1.x
  gem.add_development_dependency 'ruby_dep', '1.3.1'
  gem.add_development_dependency 'listen', '3.0.7'

  # guard-yard uses Pry which needs readline. If we're in RVM, we'll need this:
  gem.add_development_dependency 'rb-readline', '~> 0.5'

  gem.add_development_dependency 'bundler'
  gem.add_development_dependency 'cri', '~> 2'
  gem.add_development_dependency 'diplomat', '~> 0.15'
  gem.add_development_dependency 'faraday', '~> 0.9'
  gem.add_development_dependency 'ffi', '>= 1.9.9'
  gem.add_development_dependency 'git', '~> 1.2', '>= 1.2.9.1'
  gem.add_development_dependency 'guard', '~> 2.13'
  gem.add_development_dependency 'guard-bundler', '~> 2.1'
  gem.add_development_dependency 'guard-rspec', '~> 4.6.4'
  gem.add_development_dependency 'guard-rubocop', '~> 1.2'
  gem.add_development_dependency 'guard-yard', '~> 2.1'
  gem.add_development_dependency 'json', '~> 1.8.3'
  gem.add_development_dependency 'rake', '~> 10'
  gem.add_development_dependency 'rspec', '~> 3'
  gem.add_development_dependency 'rspec_junit_formatter', '~> 0.2'
  gem.add_development_dependency 'rubocop', '~> 0.37'
  gem.add_development_dependency 'simplecov', '~> 0.11'
  gem.add_development_dependency 'simplecov-console'
  gem.add_development_dependency 'yard', '~> 0.8'

  # this requires rubygems >= 2.2.0
  gem.metadata['allowed_push_host'] = 'https://rubygems.org'

  gem.files         = `git ls-files`.split($ORS)
                                    .reject { |f| f =~ %r{^samples\/} }
  gem.executables   = gem.files.grep(%r{^bin/}).map { |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = 'tfwrapper'
  gem.require_paths = ['lib']
  gem.version       = TFWrapper::VERSION
end
