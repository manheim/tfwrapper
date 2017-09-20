Version 0.3.0

  - add `tf:output` and `tf:output_json` Rake tasks
  - bump acceptance tests from terraform 0.9.2 to 0.10.2
  - Have TFWrapper::RakeTasks store the current terraform version as an instance variable;
    also make this accessible as tf_version.
  - Add '-auto-approve' to terraform apply command if running with tf >= 0.10.0

Version 0.2.0

  - initial release (migrated from previous internal/private gem)

Version 0.1.0

  - no working public release
