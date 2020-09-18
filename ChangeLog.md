Version 0.6.3

  - Fix bug with ``tf_sensitive_vars``. Prevent values from being printed in ``update_consul_stack_env_vars``.

Version 0.6.2

  - Add ``tf_sensitive_vars`` option.

Version 0.6.1

  - Add ``allowed_empty_vars`` option.
  - Only support terraform up to 0.11.14.

Version 0.6.0

  - Include full terraform output when a terraform run fails with output including ``hrottling``, ``status code: 403``, or ``status code: 401``. Previously terraform output was suppressed in these cases, which causes confusion with providers other than "aws" that include these strings in their failure output.
  - In ``Gemfile``, for testing, pin terraform-landscape gem to 0.2.2 for Ruby 2.x compatibility.
  - Pin ``rb-inotify`` dependency to 0.9.10 to allow build with Ruby < 2.2
  - Switch testing from circleci.com to travis-ci.org
  - Pin terraform_landscape dependency to 0.2.2 for compatibility with ruby < 2.5
  - Acceptance tests:
    - Use HashiCorp checkpoint API instead of GitHub Releases API to find latest terraform version, to work around query failures
    - Pin consul provider versions to 1.0.0 to fix intermittent failures
  - Switch Ruby versions used in tests to latest TravisCI versions
  - Stop acceptance testing terraform 0.9.x, as newer versions require pinning the consul provider version but 0.9 doesn't support versioned providers.

Version 0.5.1

  - Fix bug where terraform plan errors were suppressed if a plan run with landscape support enabled exited non-zero.

Version 0.5.0

  - Add support for using terraform_landscape gem, if present, to reformat plan output; see README for usage.
  - Add CircleCI testing under ruby 2.4.1, and acceptance tests for terraform 0.11.2.

Version 0.4.1

  - Upgrade rubocop, yard and diplomat development dependency versions
  - Pin `cri` development dependency to 2.9 to retain ruby 2.0 support

Version 0.4.0

  - Add support for calling Procs at the beginning and end of each task.
  - Documentation cleanup.

Version 0.3.0

  - Add `tf:output` and `tf:output_json` Rake tasks
  - Have TFWrapper::RakeTasks store the current terraform version as an instance variable;
    also make this accessible as tf_version.
  - Add '-auto-approve' to terraform apply command if running with tf >= 0.10.0
  - Update acceptance tests to work with terraform 0.9.x and 0.10.x
  - Acceptance test logic to find the latest terraform release version from GitHub API
  - Run acceptance tests for multiple terraform versions (currently: 0.9.2, 0.9.7, 0.10.0, 0.10.2, latest)

Version 0.2.0

  - initial release (migrated from previous internal/private gem)

Version 0.1.0

  - no working public release
