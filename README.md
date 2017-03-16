# tfwrapper

Build of master branch: [![CircleCI](https://circleci.com/gh/manheim/tfwrapper.svg?style=svg)](https://circleci.com/gh/manheim/tfwrapper)

Documentation: [http://www.rubydoc.info/gems/tfwrapper/](http://www.rubydoc.info/gems/tfwrapper/)

Rubygem providing rake tasks for running Hashicorp Terraform sanely

## Development

1. ``bundle install --path vendor``
2. ``bundle exec rake pre_commit`` to ensure spec tests are passing and style is valid before making your changes
3. make your changes, and write spec tests for them. You can run ``bundle exec guard`` to continually run spec tests and rubocop when files change.
4. ``bundle exec rake pre_commit`` to confirm your tests pass and your style is valid. You should confirm 100% coverage. If you wish, you can run ``bundle exec guard`` to dynamically run rspec, rubocop and YARD when relevant files change.
5. Update ``ChangeLog.md`` for your changes.
6. Run ``bundle exec rake yard:serve`` to generate documentation for your Gem and serve it live at [http://localhost:8808](http://localhost:8808), and ensure it looks correct.
7. Open a pull request for your changes.
8. When shipped, merge the PR. CircleCI will test.
9. Deployment is done locally, with ``bundle exec rake release``.

When running inside CircleCI, rspec will place reports and artifacts under the right locations for CircleCI to archive them. When running outside of CircleCI, coverage reports will be written to ``coverage/`` and test reports (HTML and JUnit XML) will be written to ``results/``.

## License

The gem is available as open source under the terms of the
[MIT License](http://opensource.org/licenses/MIT).
