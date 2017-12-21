Version 0.4.1

  - Upgrade rubocop and yard development dependency versions
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
