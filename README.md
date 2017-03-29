# tfwrapper

Build of master branch: [![CircleCI](https://circleci.com/gh/manheim/tfwrapper.svg?style=svg)](https://circleci.com/gh/manheim/tfwrapper)

Documentation: [http://www.rubydoc.info/gems/tfwrapper/](http://www.rubydoc.info/gems/tfwrapper/)

tfwrapper provides Rake tasks for working with [Hashicorp Terraform](https://www.terraform.io/) 0.9+, ensuring proper initialization and passing in variables from the environment or Ruby, as well as optionally pushing some information to Consul. tfwrapper also attempts to detect and retry
failed runs due to AWS throttling or access denied errors.

## Overview

This Gem provides the following Rake tasks:

* __tf:init__ - run ``terraform init`` to pull down dependency modules and configure remote
  state backend. This task also checks that any configured environment variables are set and
  that the ``terraform`` version is compatible with this gem.
* __tf:plan__ - run ``terraform plan`` with all variables and configuration, and TF variables written to disk. You can specify
  one or more optional [resource address](https://www.terraform.io/docs/internals/resource-addressing.html) targets to pass to
  terraform with the ``-target`` flag as Rake task arguments, i.e. ``bundle exec rake tf:plan[aws_instance.foo[1]]`` or
  ``bundle exec rake tf:plan[aws_instance.foo[1],aws_instance.bar[2]]``; see the
  [plan documentation](https://www.terraform.io/docs/commands/plan.html) for more information.
* __tf:apply__ - run ``terraform apply`` with all variables and configuration, and TF variables written to disk. You can specify
  one or more optional [resource address](https://www.terraform.io/docs/internals/resource-addressing.html) targets to pass to
  terraform with the ``-target`` flag as Rake task arguments, i.e. ``bundle exec rake tf:apply[aws_instance.foo[1]]`` or
  ``bundle exec rake tf:apply[aws_instance.foo[1],aws_instance.bar[2]]``; see the
  [apply documentation](https://www.terraform.io/docs/commands/apply.html) for more information.
* __tf:refresh__ - run ``terraform refresh``
* __tf:destroy__ - run ``terraform destroy`` with all variables and configuration, and TF variables written to disk. You can specify
  one or more optional [resource address](https://www.terraform.io/docs/internals/resource-addressing.html) targets to pass to
  terraform with the ``-target`` flag as Rake task arguments, i.e. ``bundle exec rake tf:destroy[aws_instance.foo[1]]`` or
  ``bundle exec rake tf:destroy[aws_instance.foo[1],aws_instance.bar[2]]``; see the
  [destroy documentation](https://www.terraform.io/docs/commands/destroy.html) for more information.
* __tf:write_tf_vars__ - used as a prerequisite for other tasks; write TerraForm variables to file on disk

## Installation

__Note:__ tfwrapper only supports Ruby >= 2.0.0. The effort to maintain compatibility
with 1.9.3 is simply too high to justify.

Add to your ``Gemfile``:

```
gem 'tfwrapper', '~> 0.1.0'
```

## Usage

To use the TerraForm rake tasks, require the module in your Rakefile and use the
``install_tasks`` method to set up the tasks. ``install_tasks`` takes two mandatory parameters;
``tf_dir`` specifying the relative path (from the Rakefile) to the TerraForm configuration and ``consul_prefix`` specifying the key to store state at in Consul. It also expects
the ``CONSUL_HOST`` environment variable to be set to the address of the Consul cluster used for storing state, if you are not overriding the state storage options.

```
require 'tfwrapper/raketasks'

ENV['CONSUL_HOST'] ||= 're.consul.aws-dev.manheim.com:8500'

TFWrapper::RakeTasks.install_tasks(
  'tf/',
  "terraform/re/MY_PROJECT_NAME/#{ENV['TEAM_UID']}/#{ENV['ENVIRONMENT']}"
)
```

If you wish to bind the values of environment variables to TerraForm variables, you can specify a mapping
of TerraForm variable name to environment variable name in the ``tf_vars_from_env`` option; these variables
will be automatically read from the environment and passed into TerraForm with the appropriate names. The following
example sets the ``consul_address`` terraform variable to the value of the ``CONSUL_HOST`` environment variable,
and likewise for the ``environment`` terraform variable from the ``ENVIRONMENT`` env var. It also specifies the
``consul_env_vars_prefix``, which will write the environment variables used in ``tf_vars_from_env`` and their values
to Consul at the specified path.

```
require 'tfwrapper/raketasks'
ENV['CONSUL_HOST'] ||= 're.consul.aws-dev.manheim.com:8500'
tf_env_vars = {
  'consul_address'           => 'CONSUL_HOST',
  'environment'              => 'ENVIRONMENT',
}
TFWrapper::RakeTasks.install_tasks(
  'tf/host/',
  "terraform/re/MY_PROJECT_NAME/#{ENV['TEAM_UID']}/#{ENV['ENVIRONMENT']}",
  consul_vars_prefix: "terraform/re/MY_PROJECT_NAME/#{ENV['TEAM_UID']}/#{ENV['ENVIRONMENT']}_env_vars",
  tf_vars_from_env: tf_env_vars
)
```

If you wish to explicitly bind values from your Ruby code to terraform variables, you can do this with
the ``tf_extra_vars`` option. Variables specified in this way will override same-named variables populated
via ``tf_vars_from_env``. In the following example, the ``foobar`` terraform variable will have a value
of ``baz``, regardless of what the ``FOOBAR`` environment variable is set to:

```
require 'tfwrapper/raketasks'
ENV['CONSUL_HOST'] ||= 're.consul.aws-dev.manheim.com:8500'
tf_env_vars = {
  'consul_address'           => 'CONSUL_HOST',
  'environment'              => 'ENVIRONMENT',
  'foobar'                   => 'FOOBAR',
}
TFWrapper::RakeTasks.install_tasks(
  tf_dir='tf/host/'
  consul_prefix="terraform/re/MY_PROJECT_NAME/#{ENV['TEAM_UID']}/#{ENV['ENVIRONMENT']}",
  consul_vars_prefix="terraform/re/MY_PROJECT_NAME/#{ENV['TEAM_UID']}/#{ENV['ENVIRONMENT']}_env_vars",
  tf_vars_from_env=tf_env_vars,
  tf_extra_vars={'foobar' => 'baz'}
)
```

If you need to work with multiple different Terraform configurations, this is possible
by adding a namespace prefix and using the class multiple times. The following example
will produce two sets of terraform Rake tasks; one with the default ``tf:`` namespace
that acts on the configurations under ``tf/``, and one with a ``foo_tf:`` namespace
that acts on the configurations under ``foo/``:

```
require 'tfwrapper/raketasks'
ENV['CONSUL_HOST'] ||= 're.consul.aws-dev.manheim.com:8500'
TFWrapper::RakeTasks.install_tasks(
  tf_dir='tf/'
  consul_prefix="terraform/re/MY_PROJECT_NAME/#{ENV['TEAM_UID']}/#{ENV['ENVIRONMENT']}",
)

# foo/ terraform tasks
TFWrapper::RakeTasks.install_tasks(
  tf_dir='foo/'
  consul_prefix="terraform/re/MY_PROJECT_NAME-foo/#{ENV['TEAM_UID']}/#{ENV['ENVIRONMENT']}",
  namespace_prefix='foo'
)
```

#### Non-Default Remote State Storage

To store your remote state under ``foo/bar`` in Consul:

```
require 'tfwrapper/raketasks'

ENV['CONSUL_HOST'] ||= 're.consul.aws-dev.manheim.com:8500'

TFWrapper::RakeTasks.install_tasks(
  'tf/',
  'foo/bar'
)
```

To store your state at ``terraform/#{ENV['PROJECT']}/#{ENV['ENVIRONMENT']}/terraform.tfstate``
(the default key if not otherwise specified) in the ``manheim-re`` S3 bucket in us-east-1:

```
require 'tfwrapper/raketasks'

TFWrapper::RakeTasks.install_tasks(
  'tf/',
  '',
  remote_backend_name: 's3'
)
```

To store your state at ``foo/bar/terraform.tfstate`` in the ``baz`` S3 bucket in us-west-1:

```
require 'tfwrapper/raketasks'

TFWrapper::RakeTasks.install_tasks(
  'tf/',
  '',
  remote_backend_name: 's3',
  backend_config: {
    'bucket' => 'baz',
    'key'    => 'foo/bar/terraform.tfstate',
    'region' => 'us-west-1'
  }
)
```

#### Output Buffering

If you wish to have STDOUT and STDERR from the Terraform commands run by the Rake tasks stream to the console as they run,
you will need to disable output buffering at the beginning of your Rakefile:

```ruby
STDOUT.sync = true
STDERR.sync = true
```

## Development

1. ``bundle install --path vendor``
2. ``bundle exec rake pre_commit`` to ensure spec tests are passing and style is valid before making your changes
3. make your changes, and write spec tests for them. You can run ``bundle exec guard`` to continually run spec tests and rubocop when files change.
4. ``bundle exec rake pre_commit`` to confirm your tests pass and your style is valid. You should confirm 100% coverage. If you wish, you can run ``bundle exec guard`` to dynamically run rspec, rubocop and YARD when relevant files change.
5. Update ``ChangeLog.md`` for your changes.
6. Run ``bundle exec rake yard:serve`` to generate documentation for your Gem and serve it live at [http://localhost:8808](http://localhost:8808), and ensure it looks correct.
7. Open a pull request for your changes.
8. When shipped, wait for CircleCI to test. Once shipped and tests pass, merge the PR.

When running inside CircleCI, rspec will place reports and artifacts under the right locations for CircleCI to archive them. When running outside of CircleCI, coverage reports will be written to ``coverage/`` and test reports (HTML and JUnit XML) will be written to ``results/``.

## Release Checklist

1. Ensure Circle tests are passing.
2. Build docs locally (``bundle exec rake yard:serve``) and ensure they look correct.
3. Ensure changelog entries exist for all changes since the last release.
4. Bump the version in ``lib/tfwrapper/version.rb``
5. Change the version specifier in the "Installation" section of this README, above, as appropriate.
6. Commit those changes, open a PR for the release. Once shipped and Circle passes, merge and pull down locally.
7. Deployment is done locally, with ``bundle exec rake release``.

## License

The gem is available as open source under the terms of the
[MIT License](http://opensource.org/licenses/MIT).
