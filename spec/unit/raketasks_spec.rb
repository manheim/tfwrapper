# frozen_string_literal: true

require 'spec_helper'
require 'tfwrapper/raketasks'
require 'tfwrapper/helpers'
require 'tfwrapper/version'
require 'json'
require 'retries'
require 'diplomat'
require 'rubygems'

describe TFWrapper::RakeTasks do
  subject do
    allow(Rake.application).to receive(:rakefile).and_return('Rakefile')
    allow(Rake.application).to receive(:original_dir)
      .and_return('/path/to/rakedir')
    allow(File).to receive(:realpath) { |p| p }
    subj = TFWrapper::RakeTasks.new('tfdir')
    subj.instance_variable_set('@tf_dir', 'tfdir')
    subj
  end
  describe '#install_tasks' do
    it 'calls constructor without opts if none are passed' do
      dbl = double(TFWrapper::RakeTasks)
      allow(TFWrapper::RakeTasks)
        .to receive(:new).and_return(dbl)
      allow(dbl).to receive(:install)

      expect(TFWrapper::RakeTasks).to receive(:new).once
        .with('tfdir', {})
      expect(dbl).to receive(:install).once
      TFWrapper::RakeTasks.install_tasks('tfdir')
    end
    it 'passes opts to constructor' do
      dbl = double(TFWrapper::RakeTasks)
      allow(TFWrapper::RakeTasks)
        .to receive(:new).and_return(dbl)
      allow(dbl).to receive(:install)

      expect(TFWrapper::RakeTasks).to receive(:new).once
        .with('tfdir', tf_vars_from_env: { 'foo' => 'bar' })
      expect(dbl).to receive(:install).once
      TFWrapper::RakeTasks.install_tasks(
        'tfdir', tf_vars_from_env: { 'foo' => 'bar' }
      )
    end
  end
  describe '#initialize' do
    it 'sets instance variable defaults' do
      allow(ENV).to receive(:[])
      allow(ENV).to receive(:[]).with('CONSUL_HOST').and_return('chost')
      allow(ENV).to receive(:[]).with('ENVIRONMENT').and_return('myenv')
      allow(ENV).to receive(:[]).with('PROJECT').and_return('myproj')
      allow(Rake.application).to receive(:rakefile)
        .and_return('/rake/dir/Rakefile')
      allow(File).to receive(:realpath) { |p| p.sub('../', '') }
      allow(File).to receive(:file?).and_return(true)
      cls = TFWrapper::RakeTasks.new('tfdir')
      expect(cls.instance_variable_get('@tf_dir')).to eq('/rake/dir/tfdir')
      expect(cls.instance_variable_get('@consul_env_vars_prefix')).to eq(nil)
      expect(cls.instance_variable_get('@tf_vars_from_env')).to eq({})
      expect(cls.instance_variable_get('@allowed_empty_vars')).to eq([])
      expect(cls.instance_variable_get('@tf_sensitive_vars')).to eq([])
      expect(cls.instance_variable_get('@tf_extra_vars')).to eq({})
      expect(cls.instance_variable_get('@backend_config')).to eq({})
      expect(cls.instance_variable_get('@consul_url')).to eq(nil)
      expect(cls.instance_variable_get('@tf_version'))
        .to eq(Gem::Version.new('0.0.0'))
      expect(cls.instance_variable_get('@before_proc')).to eq(nil)
      expect(cls.instance_variable_get('@after_proc')).to eq(nil)
      expect(cls.instance_variable_get('@disable_landscape')).to eq(false)
      expect(cls.instance_variable_get('@landscape_progress')).to eq(nil)
    end
    it 'sets options' do
      allow(ENV).to receive(:[])
      allow(ENV).to receive(:[]).with('CONSUL_HOST').and_return('chost')
      allow(Rake.application).to receive(:rakefile)
        .and_return('/path/to')
      allow(File).to receive(:realpath) { |p| p.sub('../', '') }
      before_dbl = double
      allow(before_dbl).to receive(:foo)
      expect(before_dbl).to_not receive(:foo)
      after_dbl = double
      allow(after_dbl).to receive(:foo)
      expect(after_dbl).to_not receive(:foo)
      bproc = Proc.new { |a, b| before_dbl.foo(a, b) }
      aproc = Proc.new { |a, b| after_dbl.foo(a, b) }
      cls = TFWrapper::RakeTasks.new(
        'tf/dir',
        consul_env_vars_prefix: 'cvprefix',
        tf_vars_from_env: { 'foo' => 'bar' },
        allowed_empty_vars: %w[bar blam],
        tf_sensitive_vars: %w[secret],
        tf_extra_vars: { 'baz' => 'blam' },
        consul_url: 'foobar',
        before_proc: bproc,
        after_proc: aproc,
        disable_landscape: true,
        landscape_progress: :dots
      )
      expect(cls.instance_variable_get('@tf_dir'))
        .to eq('/path/to/tf/dir')
      expect(cls.instance_variable_get('@consul_env_vars_prefix'))
        .to eq('cvprefix')
      expect(cls.instance_variable_get('@tf_vars_from_env'))
        .to eq('foo' => 'bar')
      expect(cls.instance_variable_get('@allowed_empty_vars'))
        .to eq(%w[bar blam])
      expect(cls.instance_variable_get('@tf_sensitive_vars'))
        .to eq(%w[secret])
      expect(cls.instance_variable_get('@tf_extra_vars'))
        .to eq('baz' => 'blam')
      expect(cls.instance_variable_get('@backend_config')).to eq({})
      expect(cls.instance_variable_get('@consul_url')).to eq('foobar')
      expect(cls.instance_variable_get('@before_proc')).to eq(bproc)
      expect(cls.instance_variable_get('@after_proc')).to eq(aproc)
      expect(cls.instance_variable_get('@disable_landscape')).to eq(true)
      expect(cls.instance_variable_get('@landscape_progress')).to eq(:dots)
    end
    context 'when before_proc is not a proc or nil' do
      it 'raises an error' do
        allow(ENV).to receive(:[])
        allow(ENV).to receive(:[]).with('CONSUL_HOST').and_return('chost')
        allow(ENV).to receive(:[]).with('ENVIRONMENT').and_return('myenv')
        allow(ENV).to receive(:[]).with('PROJECT').and_return('myproj')
        allow(Rake.application).to receive(:rakefile)
          .and_return('/rake/dir/Rakefile')
        allow(File).to receive(:realpath) { |p| p.sub('../', '') }
        allow(File).to receive(:file?).and_return(true)
        expect { TFWrapper::RakeTasks.new('tfdir', before_proc: 'foo') }
          .to raise_error(
            TypeError,
            /before_proc must be a Proc instance, not a String/
          )
      end
    end
    context 'when landscape_progress is an invalid value' do
      it 'raises an error' do
        allow(ENV).to receive(:[])
        allow(ENV).to receive(:[]).with('CONSUL_HOST').and_return('chost')
        allow(ENV).to receive(:[]).with('ENVIRONMENT').and_return('myenv')
        allow(ENV).to receive(:[]).with('PROJECT').and_return('myproj')
        allow(Rake.application).to receive(:rakefile)
          .and_return('/rake/dir/Rakefile')
        allow(File).to receive(:realpath) { |p| p.sub('../', '') }
        allow(File).to receive(:file?).and_return(true)
        expect { TFWrapper::RakeTasks.new('tfdir', landscape_progress: :foo) }
          .to raise_error(
            ArgumentError,
            /landscape_progress option must be one of:/
          )
      end
    end
    context 'when after_proc is not a proc or nil' do
      it 'raises an error' do
        allow(Rake.application).to receive(:original_dir)
          .and_return('/rake/dir')
        allow(Rake.application).to receive(:rakefile).and_return('Rakefile')
        allow(File).to receive(:realpath) { |p| p }
        expect { TFWrapper::RakeTasks.new('tfdir', after_proc: 'foo') }
          .to raise_error(
            TypeError,
            /after_proc must be a Proc instance, not a String/
          )
      end
    end
    context 'when consul_url is nil but consul_env_vars_prefix is not' do
      it 'raises an error' do
        allow(Rake.application).to receive(:original_dir)
          .and_return('/rake/dir')
        allow(Rake.application).to receive(:rakefile).and_return('Rakefile')
        allow(File).to receive(:realpath) { |p| p }
        expect do
          TFWrapper::RakeTasks.new(
            'tfdir',
            consul_env_vars_prefix: 'cvprefix',
            tf_vars_from_env: { 'foo' => 'bar' }
          )
        end.to raise_error(
          StandardError,
          'Cannot set env vars in Consul when consul_url option is nil.'
        )
      end
    end
  end
  describe '#nsprefix' do
    context 'return value' do
      it 'returns default if namespace_prefix nil' do
        subject.instance_variable_set('@ns_prefix', nil)
        expect(subject.nsprefix).to eq(:tf)
      end
      it 'prefixes namespace if namespace_prefix is not nill' do
        subject.instance_variable_set('@ns_prefix', 'foo')
        expect(subject.nsprefix).to eq(:foo_tf)
      end
    end
    context 'jobs' do
      let(:tasknames) do
        %w[
          init
          plan
          apply
          refresh
          destroy
          write_tf_vars
        ]
      end
      describe 'when namespace_prefix nil' do
        # these let/before/after come from bundler's gem_helper_spec.rb
        let!(:rake_application) { Rake.application }
        before(:each) do
          Rake::Task.clear
          Rake.application = Rake::Application.new
        end
        after(:each) do
          Rake.application = rake_application
        end
        before do
          subject.install
        end

        it 'sets the default namespace' do
          tasknames.each do |tname|
            expect(Rake.application["tf:#{tname}"])
              .to be_instance_of(Rake::Task)
          end
        end
        it 'includes the correct namespace in all dependencies' do
          tasknames.each do |tname|
            Rake.application["tf:#{tname}"].prerequisites.each do |prer|
              expect(prer.to_s).to start_with('tf:')
            end
          end
        end
      end
      describe 'when namespace_prefix set' do
        # these let/before/after come from bundler's gem_helper_spec.rb
        let!(:rake_application) { Rake.application }
        before(:each) do
          Rake::Task.clear
          Rake.application = Rake::Application.new
        end
        after(:each) do
          Rake.application = rake_application
        end
        before do
          subject.instance_variable_set('@ns_prefix', 'foo')
          subject.install
        end

        it 'sets the default namespace' do
          tasknames.each do |tname|
            expect(Rake.application["foo_tf:#{tname}"])
              .to be_instance_of(Rake::Task)
          end
        end
        it 'includes the correct namespace in all dependencies' do
          tasknames.each do |tname|
            Rake.application["foo_tf:#{tname}"].prerequisites.each do |prer|
              expect(prer.to_s).to start_with('foo_tf:')
            end
          end
        end
      end
    end
  end
  describe '#var_file_path' do
    context 'return value' do
      it 'returns default if namespace_prefix nil' do
        allow(File).to receive(:absolute_path)
          .and_return('/foo/build.tfvars.json')
        expect(File).to receive(:absolute_path).once.with('build.tfvars.json')
        subject.instance_variable_set('@ns_prefix', nil)
        expect(subject.var_file_path).to eq('/foo/build.tfvars.json')
      end
      it 'prefixes if namespace_prefix is not nill' do
        allow(File).to receive(:absolute_path)
          .and_return('/foo/foo_build.tfvars.json')
        subject.instance_variable_set('@ns_prefix', 'foo')
        expect(File).to receive(:absolute_path).once
          .with('foo_build.tfvars.json')
        expect(subject.var_file_path).to eq('/foo/foo_build.tfvars.json')
      end
    end
  end
  describe '#install' do
    it 'calls the install methods' do
      allow(subject).to receive(:install_init)
      allow(subject).to receive(:install_plan)
      allow(subject).to receive(:install_apply)
      allow(subject).to receive(:install_refresh)
      allow(subject).to receive(:install_destroy)
      allow(subject).to receive(:install_write_tf_vars)
      allow(subject).to receive(:install_output)
      expect(subject).to receive(:install_init).once
      expect(subject).to receive(:install_plan).once
      expect(subject).to receive(:install_apply).once
      expect(subject).to receive(:install_refresh).once
      expect(subject).to receive(:install_destroy).once
      expect(subject).to receive(:install_write_tf_vars).once
      expect(subject).to receive(:install_output).once
      subject.install
    end
  end
  describe '#install_init' do
    # these let/before/after come from bundler's gem_helper_spec.rb
    let!(:rake_application) { Rake.application }
    before(:each) do
      Rake::Task.clear
      Rake.application = Rake::Application.new
    end
    after(:each) do
      Rake.application = rake_application
    end
    before do
      subject.install_init
    end

    it 'adds the init task' do
      expect(Rake.application['tf:init']).to be_instance_of(Rake::Task)
    end
    it 'runs the init command with backend_config options' do
      Rake.application['tf:init'].clear_prerequisites
      expect(subject.instance_variable_get(:@tf_version))
        .to eq(Gem::Version.new('0.0.0'))
      vars = { foo: 'bar', baz: 'blam' }
      subject.instance_variable_set('@tf_vars_from_env', vars)
      subject.instance_variable_set('@allowed_empty_vars', ['bar'])
      allow(TFWrapper::Helpers).to receive(:check_env_vars)
      allow(ENV).to receive(:[])
      subject.instance_variable_set(
        '@backend_config',
        'address' => 'chost',
        'path'    => 'consulprefix',
        'foo'     => 'bar'
      )
      allow(subject).to receive(:terraform_runner)
      allow(subject).to receive(:check_tf_version)
        .and_return(Gem::Version.new('0.9.5'))
      expect(TFWrapper::Helpers)
        .to receive(:check_env_vars).once.ordered.with(vars.values, ['bar'])
      expect(subject).to receive(:check_tf_version).once.ordered
      expect(subject).to receive(:terraform_runner).once.ordered
        .with('terraform init -input=false '\
        '-backend-config=\'address=chost\'' \
        ' -backend-config=\'path=consulprefix\''\
        ' -backend-config=\'foo=bar\'')
      Rake.application['tf:init'].invoke
      expect(subject.instance_variable_get(:@tf_version))
        .to eq(Gem::Version.new('0.9.5'))
    end
    it 'runs the init command without backend_config options' do
      Rake.application['tf:init'].clear_prerequisites
      vars = { foo: 'bar', baz: 'blam' }
      subject.instance_variable_set('@tf_vars_from_env', vars)
      allow(TFWrapper::Helpers).to receive(:check_env_vars)
      allow(ENV).to receive(:[])
      subject.instance_variable_set('@backend_config', {})
      allow(subject).to receive(:terraform_runner)
      allow(subject).to receive(:check_tf_version)
        .and_return(Gem::Version.new('0.10.2'))
      expect(TFWrapper::Helpers)
        .to receive(:check_env_vars).once.ordered.with(vars.values, [])
      expect(subject).to receive(:check_tf_version).once.ordered
      expect(subject).to receive(:terraform_runner).once.ordered
        .with('terraform init -input=false')
      Rake.application['tf:init'].invoke
      expect(subject.instance_variable_get(:@tf_version))
        .to eq(Gem::Version.new('0.10.2'))
    end
    it 'calls before_proc if not nil' do
      Rake.application['tf:init'].clear_prerequisites

      before_dbl = double
      allow(before_dbl).to receive(:foo)
      expect(before_dbl).to receive(:foo).once.with('tf:init', 'tfdir')
      bproc = Proc.new { |a, b| before_dbl.foo(a, b) }
      subject.instance_variable_set('@before_proc', bproc)

      allow(TFWrapper::Helpers).to receive(:check_env_vars)
      allow(ENV).to receive(:[])
      subject.instance_variable_set('@backend_config', {})
      allow(subject).to receive(:terraform_runner)
      allow(subject).to receive(:check_tf_version)
        .and_return(Gem::Version.new('0.10.2'))
      Rake.application['tf:init'].invoke
    end
    it 'calls after_proc if not nil' do
      Rake.application['tf:init'].clear_prerequisites

      after_dbl = double
      allow(after_dbl).to receive(:foo)
      expect(after_dbl).to receive(:foo).once.with('tf:init', 'tfdir')
      aproc = Proc.new { |a, b| after_dbl.foo(a, b) }
      subject.instance_variable_set('@after_proc', aproc)

      allow(TFWrapper::Helpers).to receive(:check_env_vars)
      allow(ENV).to receive(:[])
      subject.instance_variable_set('@backend_config', {})
      allow(subject).to receive(:terraform_runner)
      allow(subject).to receive(:check_tf_version)
        .and_return(Gem::Version.new('0.10.2'))
      Rake.application['tf:init'].invoke
    end
  end
  describe '#install_plan' do
    # these let/before/after come from bundler's gem_helper_spec.rb
    let!(:rake_application) { Rake.application }
    before(:each) do
      Rake::Task.clear
      Rake.application = Rake::Application.new
      allow(subject).to receive(:landscape_format)
    end
    after(:each) do
      Rake.application = rake_application
    end
    before do
      subject.install_plan
    end

    it 'adds the plan task' do
      expect(Rake.application['tf:plan']).to be_instance_of(Rake::Task)
      expect(Rake.application['tf:plan'].prerequisites)
        .to eq(%w[tf:init tf:write_tf_vars])
      expect(Rake.application['tf:plan'].arg_names).to eq([:target])
    end
    it 'runs the plan command with no targets' do
      stub_const('TFWrapper::RakeTasks::HAVE_LANDSCAPE', true)
      Rake.application['tf:plan'].clear_prerequisites
      allow(subject).to receive(:var_file_path).and_return('file.tfvars.json')
      allow(subject).to receive(:terraform_runner)
      expect(subject).to receive(:terraform_runner).once
        .with('terraform plan -var-file file.tfvars.json', progress: nil)
      Rake.application['tf:plan'].invoke
    end
    it 'runs the plan command with one target' do
      stub_const('TFWrapper::RakeTasks::HAVE_LANDSCAPE', true)
      Rake.application['tf:plan'].clear_prerequisites
      allow(subject).to receive(:var_file_path).and_return('file.tfvars.json')
      allow(subject).to receive(:terraform_runner)
      expect(subject).to receive(:terraform_runner).once
        .with('terraform plan -var-file file.tfvars.json ' \
              '-target tar.get[1]', progress: nil)
      Rake.application['tf:plan'].invoke('tar.get[1]')
    end
    it 'runs the plan command with three targets' do
      stub_const('TFWrapper::RakeTasks::HAVE_LANDSCAPE', true)
      Rake.application['tf:plan'].clear_prerequisites
      allow(subject).to receive(:var_file_path).and_return('file.tfvars.json')
      allow(subject).to receive(:terraform_runner)
      expect(subject).to receive(:terraform_runner).once
        .with('terraform plan -var-file file.tfvars.json ' \
              '-target tar.get[1] -target t.gt[2] -target my.target[3]',
              progress: nil)
      Rake.application['tf:plan'].invoke(
        'tar.get[1]', 't.gt[2]', 'my.target[3]'
      )
    end
    context 'with terraform_landscape available and enabled' do
      before(:each) do
        stub_const('TFWrapper::RakeTasks::HAVE_LANDSCAPE', true)
        allow(subject).to receive(:var_file_path).and_return('file.tfvars.json')
        allow(subject).to receive(:terraform_runner).and_return('TFoutput')
      end
      it 'runs plan with default progress type' do
        Rake.application['tf:plan'].clear_prerequisites
        expect(subject).to receive(:terraform_runner).once
          .with('terraform plan -var-file file.tfvars.json', progress: nil)
        expect(subject).to receive(:landscape_format).once.with('TFoutput')
        Rake.application['tf:plan'].invoke
      end
      it 'runs plan with dots progress type' do
        Rake.application['tf:plan'].clear_prerequisites
        subject.instance_variable_set('@landscape_progress', :dots)
        expect(subject).to receive(:terraform_runner).once
          .with('terraform plan -var-file file.tfvars.json', progress: :dots)
        expect(subject).to receive(:landscape_format).once.with('TFoutput')
        Rake.application['tf:plan'].invoke
      end
      it 'runs plan with lines progress type' do
        Rake.application['tf:plan'].clear_prerequisites
        subject.instance_variable_set('@landscape_progress', :lines)
        expect(subject).to receive(:terraform_runner).once
          .with('terraform plan -var-file file.tfvars.json', progress: :lines)
        expect(subject).to receive(:landscape_format).once.with('TFoutput')
        Rake.application['tf:plan'].invoke
      end
      it 'runs plan with stream progress type' do
        Rake.application['tf:plan'].clear_prerequisites
        subject.instance_variable_set('@landscape_progress', :stream)
        expect(subject).to receive(:terraform_runner).once
          .with('terraform plan -var-file file.tfvars.json',
                progress: :stream)
        expect(subject).to receive(:landscape_format).once.with('TFoutput')
        Rake.application['tf:plan'].invoke
      end
    end
    context 'with terraform_landscape unavailable' do
      it 'runs plan with stream progress and does not run landscape' do
        stub_const('TFWrapper::RakeTasks::HAVE_LANDSCAPE', false)
        allow(subject).to receive(:var_file_path).and_return('file.tfvars.json')
        allow(subject).to receive(:terraform_runner).and_return('TFoutput')

        Rake.application['tf:plan'].clear_prerequisites
        expect(subject).to receive(:terraform_runner).once
          .with(
            'terraform plan -var-file file.tfvars.json', progress: :stream
          )
        expect(subject).to_not receive(:landscape_format)
        Rake.application['tf:plan'].invoke
      end
    end
    context 'with terraform_landscape available but disabled' do
      it 'runs plan with stream progress and does not run landscape' do
        stub_const('TFWrapper::RakeTasks::HAVE_LANDSCAPE', true)
        allow(subject).to receive(:var_file_path).and_return('file.tfvars.json')
        allow(subject).to receive(:terraform_runner).and_return('TFoutput')

        subject.instance_variable_set('@disable_landscape', true)
        Rake.application['tf:plan'].clear_prerequisites
        expect(subject).to receive(:terraform_runner).once
          .with(
            'terraform plan -var-file file.tfvars.json', progress: :stream
          )
        expect(subject).to_not receive(:landscape_format)
        Rake.application['tf:plan'].invoke
      end
    end
    it 'calls before_proc if not nil' do
      Rake.application['tf:plan'].clear_prerequisites
      allow(subject).to receive(:var_file_path).and_return('file.tfvars.json')
      allow(subject).to receive(:terraform_runner)

      before_dbl = double
      allow(before_dbl).to receive(:foo)
      expect(before_dbl).to receive(:foo).once.with('tf:plan', 'tfdir')
      bproc = Proc.new { |a, b| before_dbl.foo(a, b) }
      subject.instance_variable_set('@before_proc', bproc)

      Rake.application['tf:plan'].invoke
    end
    it 'calls after_proc if not nil' do
      Rake.application['tf:plan'].clear_prerequisites
      allow(subject).to receive(:var_file_path).and_return('file.tfvars.json')
      allow(subject).to receive(:terraform_runner)

      after_dbl = double
      allow(after_dbl).to receive(:foo)
      expect(after_dbl).to receive(:foo).once.with('tf:plan', 'tfdir')
      aproc = Proc.new { |a, b| after_dbl.foo(a, b) }
      subject.instance_variable_set('@after_proc', aproc)

      Rake.application['tf:plan'].invoke
    end
  end
  describe '#install_apply' do
    # these let/before/after come from bundler's gem_helper_spec.rb
    let!(:rake_application) { Rake.application }
    before(:each) do
      Rake::Task.clear
      Rake.application = Rake::Application.new
    end
    after(:each) do
      Rake.application = rake_application
    end
    before do
      subject.install_apply
    end
    it 'adds the apply task' do
      expect(Rake.application['tf:apply']).to be_instance_of(Rake::Task)
      expect(Rake.application['tf:apply'].prerequisites)
        .to eq(%w[tf:init tf:write_tf_vars tf:plan])
      expect(Rake.application['tf:apply'].arg_names).to eq([:target])
    end
    it 'calls before_proc if not nil' do
      Rake.application['tf:apply'].clear_prerequisites
      allow(subject).to receive(:var_file_path).and_return('file.tfvars.json')
      allow(subject).to receive(:terraform_runner)
      allow(subject).to receive(:update_consul_stack_env_vars)

      before_dbl = double
      allow(before_dbl).to receive(:foo)
      expect(before_dbl).to receive(:foo).once.with('tf:apply', 'tfdir')
      bproc = Proc.new { |a, b| before_dbl.foo(a, b) }
      subject.instance_variable_set('@before_proc', bproc)

      Rake.application['tf:apply'].invoke
    end
    it 'calls after_proc if not nil' do
      Rake.application['tf:apply'].clear_prerequisites
      allow(subject).to receive(:var_file_path).and_return('file.tfvars.json')
      allow(subject).to receive(:terraform_runner)
      allow(subject).to receive(:update_consul_stack_env_vars)

      after_dbl = double
      allow(after_dbl).to receive(:foo)
      expect(after_dbl).to receive(:foo).once.with('tf:apply', 'tfdir')
      aproc = Proc.new { |a, b| after_dbl.foo(a, b) }
      subject.instance_variable_set('@after_proc', aproc)

      Rake.application['tf:apply'].invoke
    end
    context 'terraform version 0.9.5' do
      before(:each) do
        allow(subject).to receive(:tf_version)
          .and_return(Gem::Version.new('0.9.5'))
      end
      it 'runs the apply command with no targets' do
        Rake.application['tf:apply'].clear_prerequisites
        allow(subject).to receive(:var_file_path).and_return('file.tfvars.json')
        allow(subject).to receive(:terraform_runner)
        allow(subject).to receive(:update_consul_stack_env_vars)
        expect(subject).to receive(:terraform_runner).once
          .with('terraform apply -var-file file.tfvars.json')
        expect(subject).to_not receive(:update_consul_stack_env_vars)
        Rake.application['tf:apply'].invoke
      end
      it 'runs the apply command with one target' do
        Rake.application['tf:apply'].clear_prerequisites
        allow(subject).to receive(:var_file_path).and_return('file.tfvars.json')
        allow(subject).to receive(:terraform_runner)
        expect(subject).to receive(:terraform_runner).once
          .with('terraform apply -var-file file.tfvars.json ' \
                '-target tar.get[1]')
        Rake.application['tf:apply'].invoke('tar.get[1]')
      end
      it 'runs the apply command with three targets' do
        Rake.application['tf:apply'].clear_prerequisites
        allow(subject).to receive(:var_file_path).and_return('file.tfvars.json')
        allow(subject).to receive(:terraform_runner)
        expect(subject).to receive(:terraform_runner).once
          .with('terraform apply -var-file file.tfvars.json ' \
                '-target tar.get[1] -target t.gt[2] -target my.target[3]')
        Rake.application['tf:apply'].invoke(
          'tar.get[1]', 't.gt[2]', 'my.target[3]'
        )
      end
      it 'runs update_consul_stack_env_vars if consul_env_vars_prefix !nil' do
        subject.instance_variable_set('@consul_env_vars_prefix', 'foo')
        Rake.application['tf:apply'].clear_prerequisites
        allow(subject).to receive(:var_file_path).and_return('file.tfvars.json')
        allow(subject).to receive(:terraform_runner)
        allow(subject).to receive(:update_consul_stack_env_vars)
        expect(subject).to receive(:terraform_runner).once
          .with('terraform apply -var-file file.tfvars.json')
        expect(subject).to receive(:update_consul_stack_env_vars).once
        Rake.application['tf:apply'].invoke
      end
    end
    context 'terraform version 0.10.2' do
      before(:each) do
        allow(subject).to receive(:tf_version)
          .and_return(Gem::Version.new('0.10.2'))
      end
      it 'runs the apply command with no targets' do
        Rake.application['tf:apply'].clear_prerequisites
        allow(subject).to receive(:var_file_path).and_return('file.tfvars.json')
        allow(subject).to receive(:terraform_runner)
        allow(subject).to receive(:update_consul_stack_env_vars)
        expect(subject).to receive(:terraform_runner).once
          .with('terraform apply -auto-approve -var-file file.tfvars.json')
        expect(subject).to_not receive(:update_consul_stack_env_vars)
        Rake.application['tf:apply'].invoke
      end
      it 'runs the apply command with one target' do
        Rake.application['tf:apply'].clear_prerequisites
        allow(subject).to receive(:var_file_path).and_return('file.tfvars.json')
        allow(subject).to receive(:terraform_runner)
        expect(subject).to receive(:terraform_runner).once
          .with('terraform apply -auto-approve -var-file file.tfvars.json ' \
                '-target tar.get[1]')
        Rake.application['tf:apply'].invoke('tar.get[1]')
      end
      it 'runs the apply command with three targets' do
        Rake.application['tf:apply'].clear_prerequisites
        allow(subject).to receive(:var_file_path).and_return('file.tfvars.json')
        allow(subject).to receive(:terraform_runner)
        expect(subject).to receive(:terraform_runner).once
          .with('terraform apply -auto-approve -var-file file.tfvars.json ' \
                '-target tar.get[1] -target t.gt[2] -target my.target[3]')
        Rake.application['tf:apply'].invoke(
          'tar.get[1]', 't.gt[2]', 'my.target[3]'
        )
      end
      it 'runs update_consul_stack_env_vars if consul_env_vars_prefix !nil' do
        subject.instance_variable_set('@consul_env_vars_prefix', 'foo')
        Rake.application['tf:apply'].clear_prerequisites
        allow(subject).to receive(:var_file_path).and_return('file.tfvars.json')
        allow(subject).to receive(:terraform_runner)
        allow(subject).to receive(:update_consul_stack_env_vars)
        expect(subject).to receive(:terraform_runner).once
          .with('terraform apply -auto-approve -var-file file.tfvars.json')
        expect(subject).to receive(:update_consul_stack_env_vars).once
        Rake.application['tf:apply'].invoke
      end
    end
  end
  describe '#install_refresh' do
    # these let/before/after come from bundler's gem_helper_spec.rb
    let!(:rake_application) { Rake.application }
    before(:each) do
      Rake::Task.clear
      Rake.application = Rake::Application.new
    end
    after(:each) do
      Rake.application = rake_application
    end
    before do
      subject.install_refresh
    end

    it 'adds the refresh task' do
      expect(Rake.application['tf:refresh']).to be_instance_of(Rake::Task)
      expect(Rake.application['tf:refresh'].prerequisites)
        .to eq(%w[tf:init tf:write_tf_vars])
    end
    it 'runs the refresh command' do
      Rake.application['tf:refresh'].clear_prerequisites
      allow(subject).to receive(:var_file_path).and_return('file.tfvars.json')
      allow(subject).to receive(:terraform_runner)
      expect(subject).to receive(:terraform_runner).once
        .with('terraform refresh -var-file file.tfvars.json')
      Rake.application['tf:refresh'].invoke
    end
    it 'calls before_proc if not nil' do
      Rake.application['tf:refresh'].clear_prerequisites
      allow(subject).to receive(:var_file_path).and_return('file.tfvars.json')
      allow(subject).to receive(:terraform_runner)

      before_dbl = double
      allow(before_dbl).to receive(:foo)
      expect(before_dbl).to receive(:foo).once.with('tf:refresh', 'tfdir')
      bproc = Proc.new { |a, b| before_dbl.foo(a, b) }
      subject.instance_variable_set('@before_proc', bproc)

      Rake.application['tf:refresh'].invoke
    end
    it 'calls after_proc if not nil' do
      Rake.application['tf:refresh'].clear_prerequisites
      allow(subject).to receive(:var_file_path).and_return('file.tfvars.json')
      allow(subject).to receive(:terraform_runner)

      after_dbl = double
      allow(after_dbl).to receive(:foo)
      expect(after_dbl).to receive(:foo).once.with('tf:refresh', 'tfdir')
      aproc = Proc.new { |a, b| after_dbl.foo(a, b) }
      subject.instance_variable_set('@after_proc', aproc)

      Rake.application['tf:refresh'].invoke
    end
  end
  describe '#install_destroy' do
    # these let/before/after come from bundler's gem_helper_spec.rb
    let!(:rake_application) { Rake.application }
    before(:each) do
      Rake::Task.clear
      Rake.application = Rake::Application.new
    end
    after(:each) do
      Rake.application = rake_application
    end
    before do
      subject.install_destroy
    end

    it 'adds the destroy task' do
      expect(Rake.application['tf:destroy']).to be_instance_of(Rake::Task)
      expect(Rake.application['tf:destroy'].prerequisites)
        .to eq(%w[tf:init tf:write_tf_vars])
      expect(Rake.application['tf:destroy'].arg_names).to eq([:target])
    end
    it 'runs the destroy command with no targets' do
      Rake.application['tf:destroy'].clear_prerequisites
      allow(subject).to receive(:var_file_path).and_return('file.tfvars.json')
      allow(subject).to receive(:terraform_runner)
      expect(subject).to receive(:terraform_runner).once
        .with('terraform destroy -force -var-file file.tfvars.json')
      Rake.application['tf:destroy'].invoke
    end
    it 'runs the destroy command with one target' do
      Rake.application['tf:destroy'].clear_prerequisites
      allow(subject).to receive(:var_file_path).and_return('file.tfvars.json')
      allow(subject).to receive(:terraform_runner)
      expect(subject).to receive(:terraform_runner).once
        .with('terraform destroy -force -var-file file.tfvars.json ' \
              '-target tar.get[1]')
      Rake.application['tf:destroy'].invoke('tar.get[1]')
    end
    it 'runs the destroy command with three targets' do
      Rake.application['tf:destroy'].clear_prerequisites
      allow(subject).to receive(:var_file_path).and_return('file.tfvars.json')
      allow(subject).to receive(:terraform_runner)
      expect(subject).to receive(:terraform_runner).once
        .with('terraform destroy -force -var-file file.tfvars.json ' \
              '-target tar.get[1] -target t.gt[2] -target my.target[3]')
      Rake.application['tf:destroy'].invoke(
        'tar.get[1]', 't.gt[2]', 'my.target[3]'
      )
    end
    it 'calls before_proc if not nil' do
      Rake.application['tf:destroy'].clear_prerequisites
      allow(subject).to receive(:var_file_path).and_return('file.tfvars.json')
      allow(subject).to receive(:terraform_runner)

      before_dbl = double
      allow(before_dbl).to receive(:foo)
      expect(before_dbl).to receive(:foo).once.with('tf:destroy', 'tfdir')
      bproc = Proc.new { |a, b| before_dbl.foo(a, b) }
      subject.instance_variable_set('@before_proc', bproc)

      Rake.application['tf:destroy'].invoke
    end
    it 'calls after_proc if not nil' do
      Rake.application['tf:destroy'].clear_prerequisites
      allow(subject).to receive(:var_file_path).and_return('file.tfvars.json')
      allow(subject).to receive(:terraform_runner)

      after_dbl = double
      allow(after_dbl).to receive(:foo)
      expect(after_dbl).to receive(:foo).once.with('tf:destroy', 'tfdir')
      aproc = Proc.new { |a, b| after_dbl.foo(a, b) }
      subject.instance_variable_set('@after_proc', aproc)

      Rake.application['tf:destroy'].invoke
    end
  end
  describe '#install_write_tf_vars' do
    # these let/before/after come from bundler's gem_helper_spec.rb
    context 'when ns_prefix is nil' do
      let!(:rake_application) { Rake.application }
      before(:each) do
        Rake::Task.clear
        Rake.application = Rake::Application.new
      end
      after(:each) do
        Rake.application = rake_application
      end
      before do
        subject.instance_variable_set('@tf_sensitive_vars', ['secret'])
        subject.install_write_tf_vars
      end

      it 'adds the write_tf_vars task' do
        expect(Rake.application['tf:write_tf_vars'])
          .to be_instance_of(Rake::Task)
        expect(Rake.application['tf:write_tf_vars'].prerequisites).to eq([])
      end
      it 'runs the write_tf_vars command' do
        vars = {
          'foo' => 'bar',
          'baz' => 'blam',
          'aws_access_key' => 'ak',
          'secret' => 'abc'
        }
        allow(subject).to receive(:terraform_vars).and_return(vars)
        allow(subject).to receive(:var_file_path).and_return('file.tfvars.json')
        f_dbl = double(File)
        allow(File).to receive(:open).and_yield(f_dbl)
        allow(f_dbl).to receive(:write)

        expect(subject).to receive(:terraform_vars).once
        expect(STDOUT).to receive(:puts).once.with('Terraform vars:')
        expect(STDOUT).to receive(:puts)
          .once.with('aws_access_key => (redacted)')
        expect(STDOUT).to receive(:puts)
          .once.with('secret => (redacted)')
        expect(STDOUT).to receive(:puts).once.with('baz => blam')
        expect(STDOUT).to receive(:puts).once.with('foo => bar')
        expect(File).to receive(:open).once.with('file.tfvars.json', 'w')
        expect(f_dbl).to receive(:write).once.with(vars.to_json)
        expect(STDERR).to receive(:puts)
          .once.with('Terraform vars written to: file.tfvars.json')
        Rake.application['tf:write_tf_vars'].invoke
      end
      it 'calls before_proc if not nil' do
        vars = {
          'foo' => 'bar',
          'baz' => 'blam',
          'aws_access_key' => 'ak'
        }
        allow(subject).to receive(:terraform_vars).and_return(vars)
        allow(subject).to receive(:var_file_path).and_return('file.tfvars.json')
        f_dbl = double(File)
        allow(File).to receive(:open).and_yield(f_dbl)
        allow(f_dbl).to receive(:write)

        before_dbl = double
        allow(before_dbl).to receive(:foo)
        expect(before_dbl).to receive(:foo).once
          .with('tf:write_tf_vars', 'tfdir')
        bproc = Proc.new { |a, b| before_dbl.foo(a, b) }
        subject.instance_variable_set('@before_proc', bproc)

        Rake.application['tf:write_tf_vars'].invoke
      end
      it 'calls after_proc if not nil' do
        vars = {
          'foo' => 'bar',
          'baz' => 'blam',
          'aws_access_key' => 'ak'
        }
        allow(subject).to receive(:terraform_vars).and_return(vars)
        allow(subject).to receive(:var_file_path).and_return('file.tfvars.json')
        f_dbl = double(File)
        allow(File).to receive(:open).and_yield(f_dbl)
        allow(f_dbl).to receive(:write)

        after_dbl = double
        allow(after_dbl).to receive(:foo)
        expect(after_dbl).to receive(:foo).once
          .with('tf:write_tf_vars', 'tfdir')
        aproc = Proc.new { |a, b| after_dbl.foo(a, b) }
        subject.instance_variable_set('@after_proc', aproc)

        Rake.application['tf:write_tf_vars'].invoke
      end
    end
    context 'when ns_prefix is specified' do
      let!(:rake_application) { Rake.application }
      before(:each) do
        Rake::Task.clear
        Rake.application = Rake::Application.new
      end
      after(:each) do
        Rake.application = rake_application
      end
      before do
        subject.instance_variable_set('@tf_sensitive_vars', ['secret'])
        subject.instance_variable_set('@ns_prefix', 'foo')
        subject.install_write_tf_vars
      end

      it 'adds the write_tf_vars task' do
        expect(Rake.application['foo_tf:write_tf_vars'])
          .to be_instance_of(Rake::Task)
        expect(Rake.application['foo_tf:write_tf_vars'].prerequisites).to eq([])
      end
      it 'runs the write_tf_vars command' do
        vars = {
          'foo' => 'bar',
          'baz' => 'blam',
          'aws_access_key' => 'ak',
          'secret' => 'abc'
        }
        allow(subject).to receive(:terraform_vars).and_return(vars)
        allow(subject).to receive(:var_file_path)
          .and_return('foo_file.tfvars.json')
        f_dbl = double(File)
        allow(File).to receive(:open).and_yield(f_dbl)
        allow(f_dbl).to receive(:write)

        expect(subject).to receive(:terraform_vars).once
        expect(STDOUT).to receive(:puts).once.with('Terraform vars:')
        expect(STDOUT).to receive(:puts)
          .once.with('aws_access_key => (redacted)')
        expect(STDOUT).to receive(:puts)
          .once.with('secret => (redacted)')
        expect(STDOUT).to receive(:puts).once.with('baz => blam')
        expect(STDOUT).to receive(:puts).once.with('foo => bar')
        expect(File).to receive(:open).once.with('foo_file.tfvars.json', 'w')
        expect(f_dbl).to receive(:write).once.with(vars.to_json)
        expect(STDERR).to receive(:puts)
          .once.with('Terraform vars written to: foo_file.tfvars.json')
        Rake.application['foo_tf:write_tf_vars'].invoke
      end
      it 'calls before_proc if not nil' do
        vars = {
          'foo' => 'bar',
          'baz' => 'blam',
          'aws_access_key' => 'ak'
        }
        allow(subject).to receive(:terraform_vars).and_return(vars)
        allow(subject).to receive(:var_file_path)
          .and_return('foo_file.tfvars.json')
        f_dbl = double(File)
        allow(File).to receive(:open).and_yield(f_dbl)
        allow(f_dbl).to receive(:write)

        before_dbl = double
        allow(before_dbl).to receive(:foo)
        expect(before_dbl).to receive(:foo).once
          .with('foo_tf:write_tf_vars', 'tfdir')
        bproc = Proc.new { |a, b| before_dbl.foo(a, b) }
        subject.instance_variable_set('@before_proc', bproc)

        Rake.application['foo_tf:write_tf_vars'].invoke
      end
      it 'calls after_proc if not nil' do
        vars = {
          'foo' => 'bar',
          'baz' => 'blam',
          'aws_access_key' => 'ak'
        }
        allow(subject).to receive(:terraform_vars).and_return(vars)
        allow(subject).to receive(:var_file_path)
          .and_return('foo_file.tfvars.json')
        f_dbl = double(File)
        allow(File).to receive(:open).and_yield(f_dbl)
        allow(f_dbl).to receive(:write)

        after_dbl = double
        allow(after_dbl).to receive(:foo)
        expect(after_dbl).to receive(:foo).once
          .with('foo_tf:write_tf_vars', 'tfdir')
        aproc = Proc.new { |a, b| after_dbl.foo(a, b) }
        subject.instance_variable_set('@after_proc', aproc)

        Rake.application['foo_tf:write_tf_vars'].invoke
      end
    end
  end
  describe '#install_output' do
    # these let/before/after come from bundler's gem_helper_spec.rb
    let!(:rake_application) { Rake.application }
    before(:each) do
      Rake::Task.clear
      Rake.application = Rake::Application.new
    end
    after(:each) do
      Rake.application = rake_application
    end
    before do
      subject.install_output
    end

    it 'adds the output task' do
      expect(Rake.application['tf:output']).to be_instance_of(Rake::Task)
      expect(Rake.application['tf:output'].prerequisites)
        .to eq(%w[tf:init tf:refresh])
    end
    it 'runs the output command' do
      Rake.application['tf:output'].clear_prerequisites
      allow(subject).to receive(:var_file_path).and_return('file.tfvars.json')
      allow(subject).to receive(:terraform_runner)
      expect(subject).to receive(:terraform_runner).once
        .with('terraform output')
      Rake.application['tf:output'].invoke
    end
    it 'output calls before_proc if not nil' do
      Rake.application['tf:output'].clear_prerequisites
      allow(subject).to receive(:var_file_path).and_return('file.tfvars.json')
      allow(subject).to receive(:terraform_runner)

      before_dbl = double
      allow(before_dbl).to receive(:foo)
      expect(before_dbl).to receive(:foo).once.with('tf:output', 'tfdir')
      bproc = Proc.new { |a, b| before_dbl.foo(a, b) }
      subject.instance_variable_set('@before_proc', bproc)

      Rake.application['tf:output'].invoke
    end
    it 'output calls after_proc if not nil' do
      Rake.application['tf:output'].clear_prerequisites
      allow(subject).to receive(:var_file_path).and_return('file.tfvars.json')
      allow(subject).to receive(:terraform_runner)

      after_dbl = double
      allow(after_dbl).to receive(:foo)
      expect(after_dbl).to receive(:foo).once.with('tf:output', 'tfdir')
      aproc = Proc.new { |a, b| after_dbl.foo(a, b) }
      subject.instance_variable_set('@after_proc', aproc)

      Rake.application['tf:output'].invoke
    end
    it 'adds the output_json task' do
      expect(Rake.application['tf:output_json']).to be_instance_of(Rake::Task)
      expect(Rake.application['tf:output_json'].prerequisites)
        .to eq(%w[tf:init tf:refresh])
    end
    it 'runs the output -json command' do
      Rake.application['tf:output_json'].clear_prerequisites
      allow(subject).to receive(:var_file_path).and_return('file.tfvars.json')
      allow(subject).to receive(:terraform_runner)
      expect(subject).to receive(:terraform_runner).once
        .with('terraform output -json')
      Rake.application['tf:output_json'].invoke
    end
    it 'output_json calls before_proc if not nil' do
      Rake.application['tf:output_json'].clear_prerequisites
      allow(subject).to receive(:var_file_path).and_return('file.tfvars.json')
      allow(subject).to receive(:terraform_runner)

      before_dbl = double
      allow(before_dbl).to receive(:foo)
      expect(before_dbl).to receive(:foo).once.with('tf:output_json', 'tfdir')
      bproc = Proc.new { |a, b| before_dbl.foo(a, b) }
      subject.instance_variable_set('@before_proc', bproc)

      Rake.application['tf:output_json'].invoke
    end
    it 'output_json calls after_proc if not nil' do
      Rake.application['tf:output_json'].clear_prerequisites
      allow(subject).to receive(:var_file_path).and_return('file.tfvars.json')
      allow(subject).to receive(:terraform_runner)

      after_dbl = double
      allow(after_dbl).to receive(:foo)
      expect(after_dbl).to receive(:foo).once.with('tf:output_json', 'tfdir')
      aproc = Proc.new { |a, b| after_dbl.foo(a, b) }
      subject.instance_variable_set('@after_proc', aproc)

      Rake.application['tf:output_json'].invoke
    end
  end
  describe '#terraform_vars' do
    it 'builds a hash and sets overrides' do
      v_from_e = { 'vfe1' => 'vfe1name', 'vfe2' => 'vfe2name' }
      extra_v = { 'ev1' => 'ev1val', 'vfe2' => 'ev_vfe2val' }
      subject.instance_variable_set('@tf_vars_from_env', v_from_e)
      subject.instance_variable_set('@tf_extra_vars', extra_v)
      allow(ENV).to receive(:[])
      allow(ENV).to receive(:[]).with('vfe1name').and_return('env_vfe1val')
      allow(ENV).to receive(:[]).with('vfe2name').and_return('env_vfe2val')
      expect(subject.terraform_vars).to eq(
        'vfe1' => 'env_vfe1val',
        'vfe2' => 'ev_vfe2val',
        'ev1' => 'ev1val'
      )
    end
  end
  describe '#landscape_format', if: HAVE_LANDSCAPE do
    before(:each) do
      allow(STDERR).to receive(:puts)
      allow(STDOUT).to receive(:puts)
    end
    context 'when no exception is raised' do
      it 'processes the string through TerraformLandscape' do
        dbl_printer = double
        dbl_output = double
        allow(TerraformLandscape::Printer)
          .to receive(:new).and_return(dbl_printer)
        allow(TerraformLandscape::Output)
          .to receive(:new).and_return(dbl_output)
        allow(dbl_printer).to receive(:process_string)

        expect(TerraformLandscape::Output)
          .to receive(:new).once.with(STDOUT)
        expect(TerraformLandscape::Printer)
          .to receive(:new).once.with(dbl_output)
        expect(dbl_printer).to receive(:process_string).once.with('PlanOutput')
        expect(STDERR).to_not receive(:puts)
        expect(STDOUT).to_not receive(:puts)
        subject.landscape_format('PlanOutput')
      end
    end
    context 'when an exception is raised' do
      context 'and landscape_progress is :stream' do
        it 'prints an error message' do
          dbl_printer = double
          dbl_output = double
          allow(TerraformLandscape::Printer)
            .to receive(:new).and_return(dbl_printer)
          allow(TerraformLandscape::Output)
            .to receive(:new).and_return(dbl_output)
          allow(dbl_printer).to receive(:process_string)
            .and_raise(RuntimeError, 'FooError')

          expect(TerraformLandscape::Output)
            .to receive(:new).once.with(STDOUT)
          expect(TerraformLandscape::Printer)
            .to receive(:new).once.with(dbl_output)
          expect(dbl_printer)
            .to receive(:process_string).once.with('PlanOutput')
          expect(STDERR).to receive(:puts).once
            .with(
              'Exception calling terraform_landscape to reformat output: ' \
              'RuntimeError: FooError'
            )
          expect(STDOUT).to_not receive(:puts)
          subject.instance_variable_set('@landscape_progress', :stream)
          subject.landscape_format('PlanOutput')
        end
      end
      context 'and landscape_progress is not :stream' do
        it 'prints an error message and then the output' do
          dbl_printer = double
          dbl_output = double
          allow(TerraformLandscape::Printer)
            .to receive(:new).and_return(dbl_printer)
          allow(TerraformLandscape::Output)
            .to receive(:new).and_return(dbl_output)
          allow(dbl_printer).to receive(:process_string)
            .and_raise(RuntimeError, 'FooError')

          expect(TerraformLandscape::Output)
            .to receive(:new).once.with(STDOUT)
          expect(TerraformLandscape::Printer)
            .to receive(:new).once.with(dbl_output)
          expect(dbl_printer)
            .to receive(:process_string).once.with('PlanOutput')
          expect(STDERR).to receive(:puts).once
            .with(
              'Exception calling terraform_landscape to reformat output: ' \
              'RuntimeError: FooError'
            )
          expect(STDOUT).to receive(:puts).once.with('PlanOutput')
          subject.instance_variable_set('@landscape_progress', nil)
          subject.landscape_format('PlanOutput')
        end
      end
    end
  end
  describe '#terraform_runner' do
    before do
      Retries.sleep_enabled = false
    end
    it 'outputs nothing and succeeds when command succeeds' do
      allow(TFWrapper::Helpers).to receive(:run_cmd_stream_output)
        .with(any_args).and_return(['MyOutput', 0])
      expect(TFWrapper::Helpers).to receive(:run_cmd_stream_output)
        .once.with('foo', 'tfdir', progress: :stream)
      expect(STDERR).to receive(:puts).once
        .with("terraform_runner command: 'foo' (in tfdir)")
      expect(STDERR).to receive(:puts).once
        .with("terraform_runner command 'foo' finished and exited 0")
      expect(subject.terraform_runner('foo')).to eq('MyOutput')
    end
    it 'retries if needed' do
      @times_called = 0
      allow(TFWrapper::Helpers).to receive(:run_cmd_stream_output) do
        @times_called += 1
        raise StandardError if @times_called == 1
        ['', 0]
      end

      expect(TFWrapper::Helpers).to receive(:run_cmd_stream_output)
        .exactly(2).times.with('foo', 'tfdir', progress: :stream)
      expect(STDERR).to receive(:puts).once
        .with("terraform_runner command: 'foo' (in tfdir)")
      expect(STDERR).to receive(:puts).once
        .with(/terraform_runner\sfailed\swith\sStandardError;\sretry\s
          attempt\s1;\s.+\sseconds\shave\spassed\./x)
      expect(STDERR).to receive(:puts).once
        .with("terraform_runner command 'foo' finished and exited 0")
      subject.terraform_runner('foo')
    end
    it 'retries if throttling' do
      @times_called = 0
      allow(TFWrapper::Helpers).to receive(:run_cmd_stream_output) do
        @times_called += 1
        if @times_called < 3
          ['foo Throttling bar', 2]
        else
          ['out', 0]
        end
      end

      expect(TFWrapper::Helpers).to receive(:run_cmd_stream_output)
        .exactly(3).times.with('foo', 'tfdir', progress: :stream)
      expect(STDERR).to receive(:puts).once
        .with("terraform_runner command: 'foo' (in tfdir)")
      expect(STDERR).to receive(:puts).once
        .with(/terraform_runner\sfailed\swith\sfoo\sThrottling\sbar\s+
          Terraform\shit\sAWS\sAPI\srate\s
          limiting;\sretry\sattempt\s1;\s.+\sseconds\shave\spassed\./x)
      expect(STDERR).to receive(:puts).once
        .with(/terraform_runner\sfailed\swith\sfoo\sThrottling\sbar\s+
          Terraform\shit\sAWS\sAPI\srate\s
          limiting;\sretry\sattempt\s2;\s.+\sseconds\shave\spassed\./x)
      expect(STDERR).to receive(:puts).once
        .with("terraform_runner command 'foo' finished and exited 0")
      expect(subject.terraform_runner('foo')).to eq('out')
    end
    it 'retries if status code 403' do
      @times_called = 0
      allow(TFWrapper::Helpers).to receive(:run_cmd_stream_output) do
        @times_called += 1
        if @times_called < 3
          ['foo status code: 403 bar', 2]
        else
          ['', 0]
        end
      end

      expect(TFWrapper::Helpers).to receive(:run_cmd_stream_output)
        .exactly(3).times.with('foo', 'tfdir', progress: :dots)
      expect(STDERR).to receive(:puts).once
        .with("terraform_runner command: 'foo' (in tfdir)")
      expect(STDERR).to receive(:puts).once
        .with(/terraform_runner\sfailed\swith\sfoo\sstatus\scode:\s403\sbar\s+
          Terraform\scommand\sgot\s403\s
        error\s-\saccess\sdenied\sor\scredentials\snot\spropagated;\sretry\s
        attempt\s1;\s.+\sseconds\shave\spassed\./x)
      expect(STDERR).to receive(:puts).once
        .with(/terraform_runner\sfailed\swith\sfoo\sstatus\scode:\s403\sbar\s+
          Terraform\scommand\sgot\s403\s
        error\s-\saccess\sdenied\sor\scredentials\snot\spropagated;\sretry\s
        attempt\s2;\s.+\sseconds\shave\spassed\./x)
      expect(STDERR).to receive(:puts).once
        .with("terraform_runner command 'foo' finished and exited 0")
      subject.terraform_runner('foo', progress: :dots)
    end
    it 'retries if status code 401' do
      @times_called = 0
      allow(TFWrapper::Helpers).to receive(:run_cmd_stream_output) do
        @times_called += 1
        if @times_called < 3
          ['foo status code: 401 bar', 2]
        else
          ['', 0]
        end
      end

      expect(TFWrapper::Helpers).to receive(:run_cmd_stream_output)
        .exactly(3).times.with('foo', 'tfdir', progress: nil)
      expect(STDERR).to receive(:puts).once
        .with("terraform_runner command: 'foo' (in tfdir)")
      expect(STDERR).to receive(:puts).once
        .with(/terraform_runner\sfailed\swith\sfoo\sstatus\scode:\s401\sbar\s+
        Terraform\scommand\sgot\s401\s
        error\s-\saccess\sdenied\sor\scredentials\snot\spropagated;\sretry\s
        attempt\s1;\s.+\sseconds\shave\spassed\./x)
      expect(STDERR).to receive(:puts).once
        .with(/terraform_runner\sfailed\swith\sfoo\sstatus\scode:\s401\sbar\s+
        Terraform\scommand\sgot\s401\s
        error\s-\saccess\sdenied\sor\scredentials\snot\spropagated;\sretry\s
        attempt\s2;\s.+\sseconds\shave\spassed\./x)
      expect(STDERR).to receive(:puts).once
        .with("terraform_runner command 'foo' finished and exited 0")
      subject.terraform_runner('foo', progress: nil)
    end
    it 'raises an error if the command exits non-zero' do
      allow(TFWrapper::Helpers).to receive(:run_cmd_stream_output)
        .and_return(['', 1])
      expect(TFWrapper::Helpers).to receive(:run_cmd_stream_output).once
        .with('foo', 'tfdir', progress: :stream)
      expect(STDERR).to receive(:puts).once
        .with('terraform_runner command: \'foo\' (in tfdir)')
      expect { subject.terraform_runner('foo') }
        .to raise_error('Errors have occurred executing: \'foo\' (exited 1)')
    end
    it 'prints output to STDERR if plan exits non-zero and not :stream' do
      allow(TFWrapper::Helpers).to receive(:run_cmd_stream_output)
        .and_return(['myoutput', 1])
      expect(TFWrapper::Helpers).to receive(:run_cmd_stream_output).once
        .with('foo', 'tfdir', progress: :dots)
      expect(STDERR).to receive(:puts).once
        .with('terraform_runner command: \'foo\' (in tfdir)')
      expect(STDERR).to receive(:puts).once
        .with('myoutput')
      expect { subject.terraform_runner('foo', progress: :dots) }
        .to raise_error('Errors have occurred executing: \'foo\' (exited 1)')
    end
    it 'raises an error if the progress option is invalid' do
      allow(TFWrapper::Helpers).to receive(:run_cmd_stream_output)
        .and_return(['', 1])
      expect(TFWrapper::Helpers).to_not receive(:run_cmd_stream_output)
      expect { subject.terraform_runner('foo', progress: :foo) }
        .to raise_error(
          'progress option must be one of: [:dots, :lines, :stream, nil]'
        )
    end
  end
  describe '#check_tf_version' do
    it 'fails if the command exits non-zero' do
      allow(TFWrapper::Helpers).to receive(:run_cmd_stream_output)
        .and_return(['myout', 2])
      allow(STDOUT).to receive(:puts)
      expect(TFWrapper::Helpers).to receive(:run_cmd_stream_output).once
        .with('terraform version', 'tfdir')
      expect(STDOUT).to_not receive(:puts)
      expect { subject.check_tf_version }
        .to raise_error(
          StandardError,
          'ERROR: \'terraform -version\' exited 2: myout'
        )
    end
    it 'strips build information from the version' do
      ver = Gem::Version.new('3.4.5')
      allow(TFWrapper::Helpers).to receive(:run_cmd_stream_output)
        .and_return(['Terraform v3.4.5-dev (abcde1234+CHANGES)', 0])
      allow(Gem::Version).to receive(:new).and_return(ver)
      expect(Gem::Version).to receive(:new).once.with('3.4.5')
      expect(subject.check_tf_version).to eq(ver)
    end
    it 'fails if the version cannot be identified' do
      allow(TFWrapper::Helpers).to receive(:run_cmd_stream_output)
        .and_return(['myout', 0])
      allow(STDOUT).to receive(:puts)
      expect(TFWrapper::Helpers).to receive(:run_cmd_stream_output).once
        .with('terraform version', 'tfdir')
      expect(STDOUT).to_not receive(:puts)
      expect { subject.check_tf_version }
        .to raise_error(
          StandardError,
          'ERROR: could not determine terraform version from \'terraform ' \
          '-version\' output: myout'
        )
    end
    it 'fails if the version is too old' do
      allow(TFWrapper::Helpers).to receive(:run_cmd_stream_output)
        .and_return(['Terraform v0.0.1-dev (foo)', 0])
      allow(STDOUT).to receive(:puts)
      expect(TFWrapper::Helpers).to receive(:run_cmd_stream_output).once
        .with('terraform version', 'tfdir')
      expect(STDOUT).to_not receive(:puts)
      expect { subject.check_tf_version }
        .to raise_error(
          StandardError,
          "ERROR: tfwrapper #{TFWrapper::VERSION} is only compatible with "\
          "Terraform >= #{subject.min_tf_version} but your terraform "\
          'binary reports itself as 0.0.1 (Terraform v0.0.1-dev (foo))'
        )
    end
    it 'prints the version if compatible' do
      allow(TFWrapper::Helpers).to receive(:run_cmd_stream_output)
        .and_return(['Terraform v999.9.9', 0])
      allow(STDOUT).to receive(:puts)
      expect(TFWrapper::Helpers).to receive(:run_cmd_stream_output).once
        .with('terraform version', 'tfdir')
      expect(STDOUT).to receive(:puts).once
        .with('Running with: Terraform v999.9.9')
      subject.check_tf_version
    end
  end
  describe '#min_tf_version' do
    it 'returns a Gem::Version for the minimum version' do
      expect(subject.min_tf_version).to eq(Gem::Version.new('0.9.0'))
    end
  end
  describe '#update_consul_stack_env_vars' do
    context 'when @consul_url and @consul_env_vars_prefix are specified' do
      it 'saves the variables in Consul' do
        vars = { 'foo' => 'bar', 'baz' => 'blam', 'secret' => 'SECRET' }
        expected = { 'bar' => 'barVal',
                     'blam' => 'blamVal',
                     'SECRET' => 'abc' }
        sanitized = { 'bar' => 'barVal',
                      'blam' => 'blamVal',
                      'SECRET' => '(redacted)' }
        subject.instance_variable_set('@tf_vars_from_env', vars)
        subject.instance_variable_set('@consul_url', 'foo://bar')
        subject.instance_variable_set('@consul_env_vars_prefix', 'my/prefix')
        subject.instance_variable_set('@tf_sensitive_vars', ['secret'])
        allow(ENV).to receive(:[])
        allow(ENV).to receive(:[]).with('CONSUL_HOST').and_return('chost')
        allow(ENV).to receive(:[]).with('bar').and_return('barVal')
        allow(ENV).to receive(:[]).with('blam').and_return('blamVal')
        allow(ENV).to receive(:[]).with('SECRET').and_return('abc')
        allow(Diplomat::Kv).to receive(:put)

        expect(STDOUT).to receive(:puts).once
          .with('Writing stack information to foo://bar at: my/prefix')
        expect(STDOUT).to receive(:puts).once
          .with(JSON.pretty_generate(sanitized))
        expect(Diplomat::Kv).to receive(:put)
          .once.with('my/prefix', JSON.generate(expected))
        subject.update_consul_stack_env_vars
        expect(Diplomat.configuration.url).to eq('foo://bar')
      end
    end
  end
  describe '#cmd_with_targets' do
    it 'creates the command string if no targets specified' do
      expect(
        subject.cmd_with_targets(
          ['terraform', 'plan', '-var-file', 'foo'],
          nil,
          nil
        )
      )
        .to eq('terraform plan -var-file foo')
    end
    it 'creates the command string with no targets and a long suffix' do
      expect(
        subject.cmd_with_targets(
          ['terraform', 'plan', '-var-file', 'foo'],
          nil,
          nil
        )
      )
        .to eq('terraform plan -var-file foo')
    end
    it 'creates the command string if one target specified' do
      expect(
        subject.cmd_with_targets(
          ['terraform', 'plan', '-var-file', 'foo'],
          'tar.get[1]',
          nil
        )
      )
        .to eq('terraform plan -var-file foo -target tar.get[1]')
    end
    it 'creates the command string if two targets specified' do
      expect(
        subject.cmd_with_targets(
          ['terraform', 'plan', '-var-file', 'foo'],
          'tar.get[1]',
          ['tar.get[2]']
        )
      )
        .to eq('terraform plan -var-file foo -target tar.get[1] ' \
               '-target tar.get[2]')
    end
    it 'creates the command string if four targets specified' do
      expect(
        subject.cmd_with_targets(
          ['terraform', 'plan', '-var-file', 'foo'],
          'tar.get[1]',
          ['tar.get[2]', 'my.target[3]']
        )
      )
        .to eq('terraform plan -var-file foo -target tar.get[1] ' \
               '-target tar.get[2] -target my.target[3]')
    end
  end
end
