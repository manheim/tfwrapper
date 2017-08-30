# frozen_string_literal: true

require_relative 'consulserver'
require_relative 'acceptance_helpers'
require 'open3'
require 'json'

TF_VERSION = '0.10.2'

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
  after(:each) { cleanup_tf }
  context 'testOne - basic TF with remote state', :order => :defined do
    before(:all) do
      @fixturepath = File.absolute_path(
        File.join(File.dirname(__FILE__), '..', 'fixtures')
      )
    end
    describe 'rake -T' do
      before(:all) do
        @out_err, @ecode = Open3.capture2e(
          'timeout -k 60 45 bundle exec rake -T',
          chdir: @fixturepath
        )
      end
      it 'does not time out' do
        expect(@ecode.exitstatus).to_not eq(124)
        expect(@ecode.exitstatus).to_not eq(137)
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
          'timeout -k 60 45 bundle exec rake tf:apply',
          chdir: @fixturepath
        )
        @varpath = File.join(@fixturepath, 'build.tfvars.json')
      end
      after(:all) do
        File.delete(@varpath) if File.file?(@varpath)
      end
      it 'does not time out' do
        expect(@ecode.exitstatus).to_not eq(124)
        expect(@ecode.exitstatus).to_not eq(137)
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
        expect(state['serial']).to eq(2)
        expect(state['modules'].length).to eq(1)
        expect(state['modules'][0]['outputs']['foo_variable']['value'])
          .to eq('bar')
        expect(state['modules'][0]['resources'])
          .to include('consul_keys.testOne')
        expect(state['modules'][0]['resources'].length).to eq(1)
      end
    end
    describe 'tf:output' do
      before(:all) do
        @out_err, @ecode = Open3.capture2e(
          'timeout -k 60 45 bundle exec rake tf:output 2>/dev/null',
          chdir: @fixturepath
        )
      end
      it 'does not time out' do
        expect(@ecode.exitstatus).to_not eq(124)
        expect(@ecode.exitstatus).to_not eq(137)
      end
      it 'exits zero' do
        expect(@ecode.exitstatus).to eq(0)
      end
      it 'shows the outputs' do
        expect(@out_err).to include('foo_variable = bar')
      end
    end
    describe 'tf:output_json' do
      before(:all) do
        @out_err, @ecode = Open3.capture2e(
          'timeout -k 60 45 bundle exec rake tf:output_json 2>/dev/null',
          chdir: @fixturepath
        )
      end
      it 'does not time out' do
        expect(@ecode.exitstatus).to_not eq(124)
        expect(@ecode.exitstatus).to_not eq(137)
      end
      it 'exits zero' do
        expect(@ecode.exitstatus).to eq(0)
      end
      it 'shows the outputs' do
        expect(@out_err).to match /.*{\s+"foo_variable": {\s+"sensitive": false,\s+"type": "string",\s+"value": "bar"\s+}\s+}.*/
      end
    end
  end
  context 'testTwo - TF with vars, remote state and consul env var update', :order => :defined do
    before(:all) do
      @fixturepath = File.absolute_path(
        File.join(File.dirname(__FILE__), '..', 'fixtures', 'testTwo')
      )
      ENV['FOO'] = 'fooval'
    end
    after(:all) do
      ENV.delete('FOO')
      ENV.delete('TFSUFFIX')
    end
    describe 'rake -T' do
      before(:all) do
        @out_err, @ecode = Open3.capture2e(
          'timeout -k 60 45 bundle exec rake -T',
          chdir: @fixturepath
        )
      end
      it 'does not time out' do
        expect(@ecode.exitstatus).to_not eq(124)
        expect(@ecode.exitstatus).to_not eq(137)
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
    describe 'tf:apply foo' do
      before(:all) do
        Diplomat::Kv.get('/', keys: true).each { |k| Diplomat::Kv.delete(k) }
        ENV['TFSUFFIX'] = 'foo'
        @out_err, @ecode = Open3.capture2e(
          'timeout -k 60 45 bundle exec rake tf:apply',
          chdir: @fixturepath
        )
        @varpath = File.join(@fixturepath, 'build.tfvars.json')
      end
      after(:all) do
        File.delete(@varpath) if File.file?(@varpath)
      end
      it 'does not time out' do
        expect(@ecode.exitstatus).to_not eq(124)
        expect(@ecode.exitstatus).to_not eq(137)
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
          .to eq('foo' => 'fooval', 'bar' => 'barval')
      end
      it 'sets the consul keys' do
        expect(Diplomat::Kv.get('testTwo/foo')).to eq('fooval')
        expect(Diplomat::Kv.get('testTwo/bar')).to eq('barval')
      end
      it 'writes remote state to consul' do
        state = JSON.parse(Diplomat::Kv.get('terraform/testTwo/foo'))
        expect(state['version']).to eq(3)
        expect(state['terraform_version']).to eq(TF_VERSION)
        expect(state['serial']).to eq(2)
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
    describe 'tf:apply bar' do
      before(:all) do
        Diplomat::Kv.get('/', keys: true).each { |k| Diplomat::Kv.delete(k) }
        ENV['TFSUFFIX'] = 'bar'
        @out_err, @ecode = Open3.capture2e(
          'timeout -k 60 45 bundle exec rake tf:apply',
          chdir: @fixturepath
        )
        @varpath = File.join(@fixturepath, 'build.tfvars.json')
      end
      after(:all) do
        File.delete(@varpath) if File.file?(@varpath)
      end
      it 'does not time out' do
        expect(@ecode.exitstatus).to_not eq(124)
        expect(@ecode.exitstatus).to_not eq(137)
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
          .to eq('foo' => 'fooval', 'bar' => 'barval')
      end
      it 'sets the consul keys' do
        expect(Diplomat::Kv.get('testTwo/foo')).to eq('fooval')
        expect(Diplomat::Kv.get('testTwo/bar')).to eq('barval')
      end
      it 'writes remote state to consul' do
        state = JSON.parse(Diplomat::Kv.get('terraform/testTwo/bar'))
        expect(state['version']).to eq(3)
        expect(state['terraform_version']).to eq(TF_VERSION)
        expect(state['serial']).to eq(2)
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
    describe 'tf:output' do
      before(:all) do
        ENV['TFSUFFIX'] = 'bar'
        @out_err, @ecode = Open3.capture2e(
          'timeout -k 60 45 bundle exec rake tf:output 2>/dev/null',
          chdir: @fixturepath
        )
        @varpath = File.join(@fixturepath, 'build.tfvars.json')
      end
      it 'does not time out' do
        expect(@ecode.exitstatus).to_not eq(124)
        expect(@ecode.exitstatus).to_not eq(137)
      end
      it 'exits zero' do
        expect(@ecode.exitstatus).to eq(0)
      end
      it 'shows the outputs' do
        expect(@out_err).to include('foo_variable = fooval')
        expect(@out_err).to include('bar_variable = barval')
      end
    end
  end
  context 'testThree - TF with namespaces', :order => :defined do
    before(:all) do
      @fixturepath = File.absolute_path(
        File.join(File.dirname(__FILE__), '..', 'fixtures', 'testThree')
      )
      ENV['FOO'] = 'fooval'
    end
    after(:all) { ENV.delete('FOO') }
    describe 'rake -T' do
      before(:all) do
        @out_err, @ecode = Open3.capture2e(
          'timeout -k 60 45 bundle exec rake -T',
          chdir: @fixturepath
        )
      end
      it 'does not time out' do
        expect(@ecode.exitstatus).to_not eq(124)
        expect(@ecode.exitstatus).to_not eq(137)
      end
      it 'exits zero' do
        expect(@ecode.exitstatus).to eq(0)
      end
      it 'lists the 15 tasks' do
        lines = @out_err.split("\n")
        expect(lines.length).to eq(15)
      end
      it 'includes the non-namespaced apply task' do
        expect(@out_err).to include('rake tf:apply[target]')
      end
      it 'includes the non-namespaced destroy task' do
        expect(@out_err).to include('rake tf:destroy[target]')
      end
      it 'includes the non-namespaced init task' do
        expect(@out_err).to include('rake tf:init')
      end
      it 'includes the non-namespaced plan task' do
        expect(@out_err).to include('rake tf:plan[target]')
      end
      it 'includes the non-namespaced write_tf_vars task' do
        expect(@out_err).to include('rake tf:write_tf_vars')
      end
      it 'includes the bar-namespaced apply task' do
        expect(@out_err).to include('rake bar_tf:apply[target]')
      end
      it 'includes the bar-namespaced destroy task' do
        expect(@out_err).to include('rake bar_tf:destroy[target]')
      end
      it 'includes the bar-namespaced init task' do
        expect(@out_err).to include('rake bar_tf:init')
      end
      it 'includes the bar-namespaced plan task' do
        expect(@out_err).to include('rake bar_tf:plan[target]')
      end
      it 'includes the bar-namespaced write_tf_vars task' do
        expect(@out_err).to include('rake bar_tf:write_tf_vars')
      end
      it 'includes the baz-namespaced apply task' do
        expect(@out_err).to include('rake baz_tf:apply[target]')
      end
      it 'includes the baz-namespaced destroy task' do
        expect(@out_err).to include('rake baz_tf:destroy[target]')
      end
      it 'includes the baz-namespaced init task' do
        expect(@out_err).to include('rake baz_tf:init')
      end
      it 'includes the baz-namespaced plan task' do
        expect(@out_err).to include('rake baz_tf:plan[target]')
      end
      it 'includes the baz-namespaced write_tf_vars task' do
        expect(@out_err).to include('rake baz_tf:write_tf_vars')
      end
    end
    describe 'tf:apply' do
      before(:all) do
        @out_err, @ecode = Open3.capture2e(
          'timeout -k 60 45 bundle exec rake tf:apply',
          chdir: @fixturepath
        )
        @varpath = File.join(@fixturepath, 'build.tfvars.json')
      end
      after(:all) do
        File.delete(@varpath) if File.file?(@varpath)
      end
      it 'does not time out' do
        expect(@ecode.exitstatus).to_not eq(124)
        expect(@ecode.exitstatus).to_not eq(137)
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
        expect(@out_err).to include('consul_keys.testThreeFoo: Creating...')
        expect(@out_err).to include(
          'Apply complete! Resources: 1 added, 0 changed, 0 destroyed.'
        )
        expect(@out_err).to include(
          "Outputs:\n\nbar_variable = barONEval\nfoo_variable = fooval"
        )
      end
      it 'writes the vars file' do
        expect(File.file?(@varpath)).to be(true)
        c = File.open(@varpath, 'r').read
        expect(JSON.parse(c))
          .to eq('foo' => 'fooval', 'bar' => 'barONEval')
      end
      it 'sets the consul keys' do
        expect(Diplomat::Kv.get('testThreeFoo/foo')).to eq('fooval')
        expect(Diplomat::Kv.get('testThreeFoo/bar')).to eq('barONEval')
      end
      it 'writes remote state to consul' do
        state = JSON.parse(Diplomat::Kv.get('terraform/testThreeFoo'))
        expect(state['version']).to eq(3)
        expect(state['terraform_version']).to eq(TF_VERSION)
        expect(state['serial']).to eq(2)
        expect(state['modules'].length).to eq(1)
        expect(state['modules'][0]['outputs']['foo_variable']['value'])
          .to eq('fooval')
        expect(state['modules'][0]['outputs']['bar_variable']['value'])
          .to eq('barONEval')
        expect(state['modules'][0]['resources'])
          .to include('consul_keys.testThreeFoo')
        expect(state['modules'][0]['resources'].length).to eq(1)
      end
    end
    describe 'tf:output' do
      before(:all) do
        @out_err, @ecode = Open3.capture2e(
          'timeout -k 60 45 bundle exec rake tf:output 2>/dev/null',
          chdir: @fixturepath
        )
        @varpath = File.join(@fixturepath, 'build.tfvars.json')
      end
      after(:all) do
        File.delete(@varpath) if File.file?(@varpath)
      end
      it 'does not time out' do
        expect(@ecode.exitstatus).to_not eq(124)
        expect(@ecode.exitstatus).to_not eq(137)
      end
      it 'exits zero' do
        expect(@ecode.exitstatus).to eq(0)
      end
      it 'shows the outputs' do
        expect(@out_err).to include('foo_variable = fooval')
        expect(@out_err).to include('bar_variable = barONEval')
      end
    end
    describe 'bar_tf:apply' do
      before(:all) do
        @out_err, @ecode = Open3.capture2e(
          'timeout -k 60 45 bundle exec rake bar_tf:apply',
          chdir: @fixturepath
        )
        @varpath = File.join(@fixturepath, 'bar_build.tfvars.json')
      end
      after(:all) do
        File.delete(@varpath) if File.file?(@varpath)
      end
      it 'does not time out' do
        expect(@ecode.exitstatus).to_not eq(124)
        expect(@ecode.exitstatus).to_not eq(137)
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
        expect(@out_err).to include('consul_keys.testThreeBar: Creating...')
        expect(@out_err).to include(
          'Apply complete! Resources: 1 added, 0 changed, 0 destroyed.'
        )
        expect(@out_err).to include(
          "Outputs:\n\nbar_variable = barTWOval\nfoo_variable = fooval"
        )
      end
      it 'writes the vars file' do
        expect(File.file?(@varpath)).to be(true)
        c = File.open(@varpath, 'r').read
        expect(JSON.parse(c))
          .to eq('foo' => 'fooval', 'bar' => 'barTWOval')
      end
      it 'sets the consul keys' do
        expect(Diplomat::Kv.get('testThreeBar/foo')).to eq('fooval')
        expect(Diplomat::Kv.get('testThreeBar/bar')).to eq('barTWOval')
      end
      it 'writes remote state to consul' do
        state = JSON.parse(Diplomat::Kv.get('terraform/testThreeBar'))
        expect(state['version']).to eq(3)
        expect(state['terraform_version']).to eq(TF_VERSION)
        expect(state['serial']).to eq(2)
        expect(state['modules'].length).to eq(1)
        expect(state['modules'][0]['outputs']['foo_variable']['value'])
          .to eq('fooval')
        expect(state['modules'][0]['outputs']['bar_variable']['value'])
          .to eq('barTWOval')
        expect(state['modules'][0]['resources'])
          .to include('consul_keys.testThreeBar')
        expect(state['modules'][0]['resources'].length).to eq(1)
      end
    end
    describe 'bar_tf:output' do
      before(:all) do
        @out_err, @ecode = Open3.capture2e(
          'timeout -k 60 45 bundle exec rake bar_tf:output 2>/dev/null',
          chdir: @fixturepath
        )
        @varpath = File.join(@fixturepath, 'bar_build.tfvars.json')
      end
      after(:all) do
        File.delete(@varpath) if File.file?(@varpath)
      end
      it 'does not time out' do
        expect(@ecode.exitstatus).to_not eq(124)
        expect(@ecode.exitstatus).to_not eq(137)
      end
      it 'exits zero' do
        expect(@ecode.exitstatus).to eq(0)
      end
      it 'shows the outputs' do
        expect(@out_err).to include('foo_variable = fooval')
        expect(@out_err).to include('bar_variable = barTWOval')
      end
    end
    describe 'baz_tf:apply' do
      before(:all) do
        @out_err, @ecode = Open3.capture2e(
          'timeout -k 60 45 bundle exec rake baz_tf:apply',
          chdir: @fixturepath
        )
        @varpath = File.join(@fixturepath, 'baz_build.tfvars.json')
      end
      after(:all) do
        File.delete(@varpath) if File.file?(@varpath)
      end
      it 'does not time out' do
        expect(@ecode.exitstatus).to_not eq(124)
        expect(@ecode.exitstatus).to_not eq(137)
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
        expect(@out_err).to include('consul_keys.testThreeBaz: Creating...')
        expect(@out_err).to include(
          'Apply complete! Resources: 1 added, 0 changed, 0 destroyed.'
        )
        expect(@out_err).to include(
          "Outputs:\n\nfoo_variable = fooval"
        )
      end
      it 'writes the vars file' do
        expect(File.file?(@varpath)).to be(true)
        c = File.open(@varpath, 'r').read
        expect(JSON.parse(c))
          .to eq('foo' => 'fooval')
      end
      it 'sets the consul keys' do
        expect(Diplomat::Kv.get('testThreeBaz/foo')).to eq('fooval')
      end
      it 'writes remote state to consul' do
        state = JSON.parse(Diplomat::Kv.get('terraform/testThreeBaz'))
        expect(state['version']).to eq(3)
        expect(state['terraform_version']).to eq(TF_VERSION)
        expect(state['serial']).to eq(2)
        expect(state['modules'].length).to eq(1)
        expect(state['modules'][0]['outputs']['foo_variable']['value'])
          .to eq('fooval')
        expect(state['modules'][0]['resources'])
          .to include('consul_keys.testThreeBaz')
        expect(state['modules'][0]['resources'].length).to eq(1)
      end
      it 'writes the environment variables to Consul' do
        cvars = JSON.parse(Diplomat::Kv.get('vars/testThreeBaz'))
        expect(cvars).to eq('FOO' => 'fooval')
      end
    end
    describe 'baz_tf:output' do
      before(:all) do
        @out_err, @ecode = Open3.capture2e(
          'timeout -k 60 45 bundle exec rake baz_tf:output 2>/dev/null',
          chdir: @fixturepath
        )
        @varpath = File.join(@fixturepath, 'baz_build.tfvars.json')
      end
      after(:all) do
        File.delete(@varpath) if File.file?(@varpath)
      end
      it 'does not time out' do
        expect(@ecode.exitstatus).to_not eq(124)
        expect(@ecode.exitstatus).to_not eq(137)
      end
      it 'exits zero' do
        expect(@ecode.exitstatus).to eq(0)
      end
      it 'shows the outputs' do
        expect(@out_err).to include('foo_variable = fooval')
        expect(@out_err).to_not include('bar_variable = ')
      end
    end
  end
end
