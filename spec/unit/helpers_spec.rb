require 'spec_helper'
require 'tfwrapper/helpers'

describe TFWrapper::Helpers do
  describe '#run_cmd' do
    it 'doesnt raise if command exits 0' do
      res = `echo -n 'myout'; exit 0`
      allow(TFWrapper::Helpers).to receive(:`).and_return(res)

      expect(STDOUT).to receive(:puts).once.with('Running command: foo bar')
      expect(TFWrapper::Helpers).to receive(:`).once.with('foo bar')
      TFWrapper::Helpers.run_cmd('foo bar')
    end
    it 'raises if command exits non-0' do
      res = `echo -n 'myout'; exit 23`
      allow(TFWrapper::Helpers).to receive(:`).and_return(res)

      expect(STDOUT).to receive(:puts).once.with('Running command: foo bar')
      expect(TFWrapper::Helpers).to receive(:`).once.with('foo bar')
      expect(STDOUT).to receive(:puts).once.with('Command exited 23:')
      expect(STDOUT).to receive(:puts).once.with('myout')
      expect { TFWrapper::Helpers.run_cmd('foo bar') }
        .to raise_error StandardError, 'ERROR: Command failed: foo bar'
    end
  end
  describe '#run_cmd_stream_output' do
    # test logic for this was inspired by:
    # http://rxr.whitequark.org/rubinius/source/spec/ruby/core/io/select_spec.rb
    before :each do
      @outerrpipe_r, @outerrpipe_w = IO.pipe
      @inpipe_r, @inpipe_w = IO.pipe
    end
    after :each do
      @outerrpipe_r.close unless @outerrpipe_r.closed?
      @outerrpipe_w.close unless @outerrpipe_w.closed?
      @inpipe_r.close unless @inpipe_r.closed?
      @inpipe_w.close unless @inpipe_w.closed?
    end
    context 'success' do
      it 'prints and returns output' do
        dbl_wait_thread = double(Thread)
        @outerrpipe_w.write('mystdout')
        @outerrpipe_w.close
        es = double('exitstatus', exitstatus: 0)
        allow(dbl_wait_thread).to receive(:value).and_return(es)
        allow($stdout).to receive(:sync).and_return(false)
        allow($stdout).to receive(:sync=).with(true)
        allow(Open3).to receive(:popen2e).and_yield(
          @inpipe_w, @outerrpipe_r, dbl_wait_thread
        )

        expect(Open3).to receive(:popen2e).once.with('foo bar')
        expect(STDOUT).to receive(:puts).once.with('mystdout')
        expect($stdout).to receive(:sync=).once.with(true)
        expect($stdout).to receive(:sync=).once.with(false)
        expect(TFWrapper::Helpers.run_cmd_stream_output('foo bar'))
          .to eq(['mystdout', 0])
      end
    end
    context 'IOError' do
      it 'handles IOErrors gracefully' do
        dbl_wait_thread = double(Thread)
        @outerrpipe_w.close
        @outerrpipe_r.close
        es = double('exitstatus', exitstatus: 0)
        allow(dbl_wait_thread).to receive(:value).and_return(es)
        allow($stdout).to receive(:sync).and_return(false)
        allow($stdout).to receive(:sync=).with(true)
        allow(Open3).to receive(:popen2e).and_yield(
          @inpipe_w, @outerrpipe_r, dbl_wait_thread
        )

        expect(Open3).to receive(:popen2e).once.with('foo bar')
        expect(STDERR).to receive(:puts).once.with('IOError: closed stream')
        expect($stdout).to receive(:sync=).once.with(true)
        expect($stdout).to receive(:sync=).once.with(false)
        expect(TFWrapper::Helpers.run_cmd_stream_output('foo bar'))
          .to eq(['', 0])
      end
    end
    context 'failure' do
      it 'returns the non-zero exit code' do
        dbl_wait_thread = double(Thread)
        @outerrpipe_w.write("mystdout\n")
        @outerrpipe_w.write("STDERR\n")
        @outerrpipe_w.close
        es = double('exitstatus', exitstatus: 23)
        allow(dbl_wait_thread).to receive(:value).and_return(es)
        allow($stdout).to receive(:sync).and_return(false)
        allow($stdout).to receive(:sync=).with(true)
        allow(Open3).to receive(:popen2e).and_yield(
          @inpipe_w, @outerrpipe_r, dbl_wait_thread
        )

        expect(Open3).to receive(:popen2e).once.with('foo bar')
        expect(STDOUT).to receive(:puts).once.with("mystdout\n")
        expect(STDOUT).to receive(:puts).once.with("STDERR\n")
        expect($stdout).to receive(:sync=).once.with(true)
        expect($stdout).to receive(:sync=).once.with(false)
        expect(TFWrapper::Helpers.run_cmd_stream_output('foo bar'))
          .to eq(["mystdout\nSTDERR\n", 23])
      end
    end
  end
  describe '#check_env_vars' do
    it 'returns nil if vars present' do
      ENV['foo'] = 'fooval'
      ENV['bar'] = 'barval'
      expect(TFWrapper::Helpers.check_env_vars(%w(foo bar))).to be_nil
      ENV.delete('foo')
      ENV.delete('bar')
    end
    it 'exits if not present' do
      ENV.delete('foo')
      ENV.delete('bar')
      expect(STDOUT).to receive(:puts)
        .with('ERROR: Environment variable \'foo\' must be set.')
      expect(STDOUT).to receive(:puts)
        .with('ERROR: Environment variable \'bar\' must be set.')
      expect { TFWrapper::Helpers.check_env_vars(%w(foo bar)) }
        .to raise_error StandardError, 'Missing or empty environment ' \
          'variables: ["foo", "bar"]'
    end
    it 'exits if empty' do
      ENV['foo'] = ''
      ENV['bar'] = '    '
      expect(STDOUT).to receive(:puts)
        .with("ERROR: Environment variable 'foo' must not be empty.")
      expect(STDOUT).to receive(:puts)
        .with("ERROR: Environment variable 'bar' must not be empty.")
      expect { TFWrapper::Helpers.check_env_vars(%w(foo bar)) }
        .to raise_error StandardError, 'Missing or empty environment ' \
          'variables: ["foo", "bar"]'
      ENV.delete('foo')
      ENV.delete('bar')
    end
  end
end
