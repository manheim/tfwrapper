# frozen_string_literal: true

require_relative 'consulserver'
require_relative 'acceptance_helpers'
require 'open3'
require 'json'

TF_VERSION = '0.9.2'

Diplomat.configure do |config|
  config.url = 'http://127.0.0.1:8500'
end

describe 'tfwrapper' do
  before(:all) do
    tf_path = File.dirname(HashicorpFetcher.new('terraform', TF_VERSION).fetch)
    ENV['PATH'] = "#{tf_path}:#{ENV['PATH']}"
    @server = ConsulServer.new
  end
  after(:all) do
    @server.stop
  end
  context 'testOne - basic TF with remote state' do
    before(:all) do
      @fixturepath = File.absolute_path(
        File.join(File.dirname(__FILE__), '..', 'fixtures')
      )
    end
    describe 'rake -T' do
      before(:all) do
        @out_err, @ecode = Open3.capture2e(
          'bundle exec rake -T',
          chdir: @fixturepath
        )
      end
      it 'exits zero' do
        expect(@ecode.exitstatus).to eq(0)
      end
      it 'lists the 5 tasks' do
        lines = @out_err.split("\n")
        expect(lines.length).to eq(5)
      end
      it 'includes the apply task' do
        expect(@out_err).to include('rake tf:apply[target]')
      end
      it 'includes the destroy task' do
        expect(@out_err).to include('rake tf:destroy[target]')
      end
      it 'includes the init task' do
        expect(@out_err).to include('rake tf:init')
      end
      it 'includes the plan task' do
        expect(@out_err).to include('rake tf:plan[target]')
      end
      it 'includes the write_tf_vars task' do
        expect(@out_err).to include('rake tf:write_tf_vars')
      end
    end
    describe 'tf:apply' do
      before(:all) do
        @out_err, @ecode = Open3.capture2e(
          'bundle exec rake tf:apply',
          chdir: @fixturepath
        )
        @varpath = File.join(@fixturepath, 'build.tfvars.json')
      end
      after(:all) do
        File.delete(@varpath) if File.file?(@varpath)
      end
      it 'exits zero' do
        expect(@ecode.exitstatus).to eq(0)
      end
      it 'uses the correct Terraform version' do
        expect(@out_err).to include("Terraform v#{TF_VERSION}")
      end
      it 'runs apply correctly and succeeds' do
        expect(@out_err)
          .to include('terraform_runner command: \'terraform apply -var-file')
        expect(@out_err).to include('consul_keys.testOne: Creating...')
        expect(@out_err).to include(
          'Apply complete! Resources: 1 added, 0 changed, 0 destroyed.'
        )
        expect(@out_err).to include("Outputs:\n\nfoo_variable = bar")
      end
      it 'writes the vars file' do
        expect(File.file?(@varpath)).to be(true)
        c = File.open(@varpath, 'r').read
        expect(JSON.parse(c)).to eq({})
      end
      it 'sets the consul key' do
        expect(Diplomat::Kv.get('testOne')).to eq('bar')
      end
      it 'writes remote state to consul' do
        state = JSON.parse(Diplomat::Kv.get('terraform/testOne'))
        expect(state['version']).to eq(3)
        expect(state['terraform_version']).to eq(TF_VERSION)
        expect(state['serial']).to eq(1)
        expect(state['modules'].length).to eq(1)
        expect(state['modules'][0]['outputs']['foo_variable']['value'])
          .to eq('bar')
        expect(state['modules'][0]['resources'])
          .to include('consul_keys.testOne')
        expect(state['modules'][0]['resources'].length).to eq(1)
      end
    end
  end
  context 'testTwo - TF with vars, remote state and consul env var update' do
    before(:all) do
      @fixturepath = File.absolute_path(
        File.join(File.dirname(__FILE__), '..', 'fixtures', 'testTwo')
      )
      ENV['FOO'] = 'fooval'
    end
    after(:all) { ENV.delete('FOO') }
    describe 'rake -T' do
      before(:all) do
        @out_err, @ecode = Open3.capture2e(
          'bundle exec rake -T',
          chdir: @fixturepath
        )
      end
      it 'exits zero' do
        expect(@ecode.exitstatus).to eq(0)
      end
      it 'lists the 5 tasks' do
        lines = @out_err.split("\n")
        expect(lines.length).to eq(5)
      end
      it 'includes the apply task' do
        expect(@out_err).to include('rake tf:apply[target]')
      end
      it 'includes the destroy task' do
        expect(@out_err).to include('rake tf:destroy[target]')
      end
      it 'includes the init task' do
        expect(@out_err).to include('rake tf:init')
      end
      it 'includes the plan task' do
        expect(@out_err).to include('rake tf:plan[target]')
      end
      it 'includes the write_tf_vars task' do
        expect(@out_err).to include('rake tf:write_tf_vars')
      end
    end
    describe 'tf:apply' do
      before(:all) do
        @out_err, @ecode = Open3.capture2e(
          'bundle exec rake tf:apply',
          chdir: @fixturepath
        )
        @varpath = File.join(@fixturepath, 'build.tfvars.json')
      end
      after(:all) do
        File.delete(@varpath) if File.file?(@varpath)
      end
      it 'exits zero' do
        expect(@ecode.exitstatus).to eq(0)
      end
      it 'uses the correct Terraform version' do
        expect(@out_err).to include("Terraform v#{TF_VERSION}")
      end
      it 'runs apply correctly and succeeds' do
        expect(@out_err)
          .to include('terraform_runner command: \'terraform apply -var-file')
        expect(@out_err).to include('consul_keys.testTwo: Creating...')
        expect(@out_err).to include(
          'Apply complete! Resources: 1 added, 0 changed, 0 destroyed.'
        )
        expect(@out_err).to include(
          "Outputs:\n\nbar_variable = barval\nfoo_variable = fooval"
        )
      end
      it 'writes the vars file' do
        expect(File.file?(@varpath)).to be(true)
        c = File.open(@varpath, 'r').read
        expect(JSON.parse(c))
          .to eq({'foo' => 'fooval', 'bar' => 'barval'})
      end
      it 'sets the consul keys' do
        expect(Diplomat::Kv.get('testTwo/foo')).to eq('fooval')
        expect(Diplomat::Kv.get('testTwo/bar')).to eq('barval')
      end
      it 'writes remote state to consul' do
        state = JSON.parse(Diplomat::Kv.get('terraform/testTwo'))
        expect(state['version']).to eq(3)
        expect(state['terraform_version']).to eq(TF_VERSION)
        expect(state['serial']).to eq(1)
        expect(state['modules'].length).to eq(1)
        expect(state['modules'][0]['outputs']['foo_variable']['value'])
          .to eq('fooval')
        expect(state['modules'][0]['outputs']['bar_variable']['value'])
          .to eq('barval')
        expect(state['modules'][0]['resources'])
          .to include('consul_keys.testTwo')
        expect(state['modules'][0]['resources'].length).to eq(1)
      end
    end
  end
  context 'TF with multiple runs to different state paths, via namespaces'
end
