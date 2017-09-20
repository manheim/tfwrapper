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
  [apply documentation](https://www.terraform.io/docs/commands/apply.html) for more information. This also runs a plan first.
* __tf:refresh__ - run ``terraform refresh``
* __tf:destroy__ - run ``terraform destroy`` with all variables and configuration, and TF variables written to disk. You can specify
  one or more optional [resource address](https://www.terraform.io/docs/internals/resource-addressing.html) targets to pass to
  terraform with the ``-target`` flag as Rake task arguments, i.e. ``bundle exec rake tf:destroy[aws_instance.foo[1]]`` or
  ``bundle exec rake tf:destroy[aws_instance.foo[1],aws_instance.bar[2]]``; see the
  [destroy documentation](https://www.terraform.io/docs/commands/destroy.html) for more information.
* __tf:write_tf_vars__ - used as a prerequisite for other tasks; write Terraform variables to file on disk

## Installation

__Note:__ tfwrapper only supports Ruby >= 2.0.0. The effort to maintain compatibility
with 1.9.3 is simply too high to justify.

Add to your ``Gemfile``:

```ruby
gem 'tfwrapper', '~> 0.2.0'
```

### Supported Terraform Versions

tfwrapper only supports terraform 0.9+. It is tested against multiple versions from 0.9.2 to 0.10.2 and the current release.

## Usage

To use the Terraform rake tasks, require the module in your Rakefile and use the
``install_tasks`` method to set up the tasks. ``install_tasks`` takes one mandatory parameter,
``tf_dir`` specifying the relative path (from the Rakefile) to the Terraform configuration.

For a directory layout like:

```
.
├── bar.tf
├── foo.tf
├── main.tf
└── Rakefile
```

The minimal ``Rakefile`` would be:

```ruby
require 'tfwrapper/raketasks'

TFWrapper::RakeTasks.install_tasks('.')
```

``rake -T`` output:

```
rake tf:apply[target]        # Apply a terraform plan that will provision your resources; specify optional CSV targets
rake tf:destroy[target]      # Destroy any live resources that are tracked by your state files; specify optional CSV targets
rake tf:init                 # Run terraform init with appropriate arguments
rake tf:plan[target]         # Output the set plan to be executed by apply; specify optional CSV targets
rake tf:write_tf_vars        # Write PWD/build.tfvars.json
```

You can also point ``tf_dir`` to an arbitrary directory relative to the Rakefile, such as when your terraform
configurations are nested below the Rakefile:

```
.
├── infrastructure
│   └── terraform
│       ├── bar.tf
│       ├── foo.tf
│       └── main.tf
├── lib
├── Rakefile
└── spec
```

Rakefile:

```ruby
require 'tfwrapper/raketasks'

TFWrapper::RakeTasks.install_tasks('infrastructure/terraform')
```

### Environment Variables to Terraform Variables

If you wish to bind the values of environment variables to Terraform variables, you can specify a mapping
of Terraform variable name to environment variable name in the ``tf_vars_from_env`` option; these variables
will be automatically read from the environment and passed into Terraform with the appropriate names. The following
example sets the ``consul_address`` terraform variable to the value of the ``CONSUL_HOST`` environment variable
(defaulting it to ``consul.example.com:8500`` if it is not already set in the environment),
and likewise for the ``environment`` terraform variable from the ``ENVIRONMENT`` env var.

```ruby
require 'tfwrapper/raketasks'
ENV['CONSUL_HOST'] ||= 'consul.example.com:8500'

TFWrapper::RakeTasks.install_tasks(
  '.',
  tf_vars_from_env: {
    'consul_address'           => 'CONSUL_HOST',
    'environment'              => 'ENVIRONMENT',
  }
)
```

### Ruby Variables to Terraform Variables

If you wish to explicitly bind values from your Ruby code to terraform variables, you can do this with
the ``tf_extra_vars`` option. Variables specified in this way will override same-named variables populated
via ``tf_vars_from_env``. In the following example, the ``foobar`` terraform variable will have a value
of ``baz``, regardless of what the ``FOOBAR`` environment variable is set to, and the ``hostname``
terraform variable will be set to the hostname (``Socket.gethostname``) of the system Rake is running on:

```ruby
require 'socket'
require 'tfwrapper/raketasks'

ENV['FOOBAR'] ||= 'not_baz'

TFWrapper::RakeTasks.install_tasks(
  '.',
  tf_vars_from_env: {
    'foobar' => 'FOOBAR'
  },
  tf_extra_vars: {
    'foobar'   => 'baz',
    'hostname' => Socket.gethostname
  }
)
```

### Namespace Prefixes for Multiple Configurations

If you need to work with multiple different Terraform configurations, this is possible
by adding a namespace prefix and calling ``install_tasks`` multiple times. The following example
will produce two sets of terraform Rake tasks; one with the default ``tf:`` namespace
that acts on the configurations under ``tf/foo``, and one with a ``bar_tf:`` namespace
that acts on the configurations under ``tf/bar``. You can use as many namespaces as
you want.

Directory tree:

```
.
├── Rakefile
└── tf
    ├── bar
    │   └── bar.tf
    └── foo
        └── foo.tf
```

Rakefile:

```ruby
require 'tfwrapper/raketasks'

# foo/ (default) terraform tasks
TFWrapper::RakeTasks.install_tasks('tf/foo')

# bar/ terraform tasks
TFWrapper::RakeTasks.install_tasks('tf/bar', namespace_prefix: 'bar')
```

``rake -T`` output:

```
rake bar_tf:apply[target]    # Apply a terraform plan that will provision your resources; specify optional CSV targets
rake bar_tf:destroy[target]  # Destroy any live resources that are tracked by your state files; specify optional CSV targets
rake bar_tf:init             # Run terraform init with appropriate arguments
rake bar_tf:plan[target]     # Output the set plan to be executed by apply; specify optional CSV targets
rake bar_tf:write_tf_vars    # Write PWD/bar_build.tfvars.json
rake tf:apply[target]        # Apply a terraform plan that will provision your resources; specify optional CSV targets
rake tf:destroy[target]      # Destroy any live resources that are tracked by your state files; specify optional CSV targets
rake tf:init                 # Run terraform init with appropriate arguments
rake tf:plan[target]         # Output the set plan to be executed by apply; specify optional CSV targets
rake tf:write_tf_vars        # Write PWD/build.tfvars.json
```

### Backend Configuration Options

``install_tasks`` accepts a ``backend_config`` hash of options to pass as backend configuration
to ``terraform init`` via the ``-backend-config='key=value'`` command line argument. This can
be used when you need to pass some backend configuration in from the environment, such as a
specific remote state storage path, credentials, etc.

For a simple example, assume we aren't using [state environments](https://www.terraform.io/docs/state/environments.html)
but instead opt to use specific paths based on a ``ENVIRONMENT`` environment variable.

Our terraform configuration might include something like:

```
terraform {
  required_version = "> 0.9.0"
  backend "consul" {
    address = "consul.example.com:8500"
  }
}

variable "environment" {}
```

And the Rakefile would pass in the path to store state in Consul, as well as
passing the ``ENVIRONMENT`` env var into Terraform for use:

```ruby
require 'tfwrapper/raketasks'

TFWrapper::RakeTasks.install_tasks(
  '.',
  tf_vars_from_env: {'environment' => 'ENVIRONMENT'},
  backend_config: {'path' => "terraform/foo/#{ENVIRONMENT}"}
)
```

### Environment Variables to Consul

tfwrapper also includes functionality to push environment variables to Consul
(as a JSON object) after a successful apply. This is mainly useful when running
tfwrapper from within Jenkins or another job runner, where they can be used to
pre-populate user input fields on subsequent runs. This is configured via the
``consul_url`` and ``consul_env_vars_prefix`` options:

Example Terraform snippet:

```
variable "foo" {}
variable "bar" {}
```

Rakefile:

```ruby
require 'tfwrapper/raketasks'

TFWrapper::RakeTasks.install_tasks(
  '.',
  tf_vars_from_env: {'foo' => 'FOO', 'bar' => 'BAR'},
  consul_url: 'http://consul.example.com:8500',
  consul_env_vars_prefix: 'terraform/inputs/foo'
)
```

After a successful terraform apply, e.g.:

```
FOO=one BAR=two bundle exec rake tf:apply
```

The key in Consul at ``terraform/inputs/foo`` will be set to a JSON hash of the
environment variables used via ``tf_vars_from_env`` and their values:

```shell
$ consul kv get terraform/inputs/foo
{"FOO":"one", "BAR":"two"}
```

## Development

1. ``bundle install --path vendor``
2. ``bundle exec rake pre_commit`` to ensure unit tests are passing and style is valid before making your changes.
3. ``bundle exec rake spec:acceptance`` to ensure acceptance tests are passing before making your changes.
4. make your changes, and write unit tests for them. If you introduced user-visible (public API) changes, write acceptance tests for them. You can run ``bundle exec guard`` to continually run unit tests and rubocop when files change.
5. ``bundle exec rake pre_commit`` to confirm your unit tests pass and your style is valid. You should confirm 100% coverage. If you wish, you can run ``bundle exec guard`` to dynamically run rspec, rubocop and YARD when relevant files change.
6. ``bundle exec rake spec:acceptance`` to ensure acceptance tests are passing.
7. Update ``ChangeLog.md`` for your changes.
8. Run ``bundle exec rake yard:serve`` to generate documentation for your Gem and serve it live at [http://localhost:8808](http://localhost:8808), and ensure it looks correct.
9. Open a pull request for your changes.
10. When shipped, wait for CircleCI to test. Once shipped and tests pass, merge the PR.

When running inside CircleCI, rspec will place reports and artifacts under the right locations for CircleCI to archive them. When running outside of CircleCI, coverage reports will be written to ``coverage/`` and test reports (HTML and JUnit XML) will be written to ``results/``.

### Acceptance Tests

This gem includes some rspec-based acceptance tests, runnable via ``bundle exec rake spec:acceptance``. These tests download
a specific version of Terraform and Consul, run a local Consul server (in ``-dev`` mode), and actually run ``terraform`` via
``rake`` and confirm that Terraform both runs correctly and correctly updates state in Consul. The terraform configurations
and rakefiles used can be found in ``spec/acceptance``. The terraform configurations use only the
[consul](https://www.terraform.io/docs/providers/consul/index.html) provider, to remove any external dependencies other than
Consul (which is already used to test remote state).

Note that the acceptance tests depend on the GNU coreutils ``timeout`` command.

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
