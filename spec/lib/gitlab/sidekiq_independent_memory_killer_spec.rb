# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::SidekiqIndependentMemoryKiller do
  let(:memory_killer) { described_class.new }
  let(:pid) { 12345 }
  before do
    allow(memory_killer).to receive(:pid).and_return(pid)
    allow(Sidekiq.logger).to receive(:info)
    allow(Sidekiq.logger).to receive(:warn)
  end

  describe '#start_working' do
    subject { memory_killer.send(:start_working) }

    before do
      # let enalbed? return 4 times: true, true, false
      allow(memory_killer).to receive(:enabled?).and_return(true, true, false)
    end

    context 'when structured logging is used' do
      it 'logs start message once' do
        expect(Sidekiq.logger).to receive(:info).once
          .with(
            class: described_class.to_s,
            action: 'start',
            message: "Starting SidekiqIndependentMemoryKiller Daemon. pid: #{pid}")

        subject
      end

      it 'logs exception message twice' do
        expect(Sidekiq.logger).to receive(:warn).twice
          .with(
            class: described_class.to_s,
            message: "Exception from #{described_class}#start_working: My Exception")

        expect(memory_killer).to receive(:check_rss).twice.and_raise(Exception, 'My Exception')

        expect { subject }.not_to raise_exception
      end

      it 'logs stop message once' do
        expect(Sidekiq.logger).to receive(:warn).once
          .with(
            class: described_class.to_s,
            action: 'stop',
            message: "Stopping SidekiqIndependentMemoryKiller Daemon. pid: #{pid}")

        subject
      end
    end

    it 'invoke check_rss twice' do
      expect(memory_killer).to receive(:check_rss).twice

      subject
    end
  end

  describe '#stop_working' do
    it 'changed enable? to false' do
      expect(memory_killer.send(:enabled?)).to be true
      memory_killer.send(:stop_working)
      expect(memory_killer.send(:enabled?)).to be false
    end
  end

  describe '#check_rss' do
    subject { memory_killer.send(:check_rss) }
    let(:grace_time) { 6 }
    let(:shutdown_time) { 7 }
    let(:check_interval) { 2 }
    let(:grace_balloon_seconds) { 5 }

    before do
      stub_const("#{described_class}::GRACE_TIME", grace_time)
      stub_const("#{described_class}::SHUTDOWN_WAIT", shutdown_time)
      stub_const("#{described_class}::CHECK_INTERVAL_SECONDS", check_interval)
      stub_const("#{described_class}::GRACE_BALLOON_SECONDS", grace_balloon_seconds)
      allow(memory_killer).to receive(:pid).and_return(pid)
      allow(Process).to receive(:getpgrp).and_return(pid)
      allow(Sidekiq).to receive(:options).and_return(timeout: 3)
    end

    it 'does not signal when everything is within limit' do
      expect(memory_killer).to receive(:get_rss).and_return(100)
      expect(memory_killer).to receive(:soft_limit_rss).and_return(200)
      expect(memory_killer).to receive(:hard_limit_rss).and_return(300)

      expect(Time).not_to receive(:now)
      expect(memory_killer).not_to receive(:signal_and_wait)
      expect(memory_killer).not_to receive(:signal_pgroup)

      subject
    end

    it 'send signal when rss exceeds hard_limit_rss' do
      expect(memory_killer).to receive(:get_rss).and_return(400)
      expect(memory_killer).to receive(:soft_limit_rss).and_return(200)
      expect(memory_killer).to receive(:hard_limit_rss).and_return(300)

      expect(Time).to receive(:now).twice
      expect(memory_killer).to receive(:signal_and_wait).with(grace_time, 'SIGTSTP', 'stop fetching new jobs').ordered
      expect(memory_killer).to receive(:signal_and_wait).with(shutdown_time, 'SIGTERM', 'gracefully shut down').ordered
      expect(memory_killer).to receive(:signal_pgroup).with(5, 'SIGKILL', 'die').ordered

      subject
    end

    it 'send signal when rss exceed hard_limit_rss after a while' do
      expect(memory_killer).to receive(:get_rss).and_return(250, 400)
      expect(memory_killer).to receive(:soft_limit_rss).and_return(200, 200)
      expect(memory_killer).to receive(:hard_limit_rss).and_return(300, 300)

      expect(Time).to receive(:now).exactly(3).times
      expect(memory_killer).to receive(:sleep).with(check_interval)

      expect(memory_killer).to receive(:signal_and_wait).with(grace_time, 'SIGTSTP', 'stop fetching new jobs').ordered
      expect(memory_killer).to receive(:signal_and_wait).with(shutdown_time, 'SIGTERM', 'gracefully shut down').ordered
      expect(memory_killer).to receive(:signal_pgroup).with(5, 'SIGKILL', 'die').ordered

      subject
    end

    it 'does not send signal when rss below soft_limit_rss after a while within GRACE_BALLOON_SECONDS' do
      expect(memory_killer).to receive(:get_rss).and_return(250, 100)
      expect(memory_killer).to receive(:soft_limit_rss).and_return(200, 200, 200)
      expect(memory_killer).to receive(:hard_limit_rss).and_return(300, 300)

      expect(Time).to receive(:now).exactly(3).times
      expect(memory_killer).to receive(:sleep).with(check_interval)

      expect(memory_killer).not_to receive(:signal_and_wait)
      expect(memory_killer).not_to receive(:signal_pgroup)

      subject
    end

    it 'send signal when rss exceed soft_limit_rss longer than GRACE_BALLOON_SECONDS' do
      expect(memory_killer).to receive(:get_rss).and_return(250, 250, 250, 250)
      expect(memory_killer).to receive(:soft_limit_rss).and_return(200, 200, 200, 200)
      expect(memory_killer).to receive(:hard_limit_rss).and_return(300, 300, 300)

      expect(Time).to receive(:now).at_least(5).times.and_call_original
      expect(memory_killer).to receive(:sleep).at_least(3).times.with(check_interval).and_call_original

      expect(memory_killer).to receive(:signal_and_wait).with(grace_time, 'SIGTSTP', 'stop fetching new jobs').ordered
      expect(memory_killer).to receive(:signal_and_wait).with(shutdown_time, 'SIGTERM', 'gracefully shut down').ordered
      expect(memory_killer).to receive(:signal_pgroup).with(5, 'SIGKILL', 'die').ordered

      subject
    end
  end

  describe '#signal_and_wait' do
    subject { memory_killer.send(:signal_and_wait, time, signal, explanation) }
    let(:time) { 2 }
    let(:signal) { 'my-signal' }
    let(:explanation) { 'my-explanation' }

    it 'send signal and return when all jobs finished' do
      expect(Process).to receive(:kill).with(signal, pid).ordered
      expect(Time).to receive(:now).and_call_original

      expect(memory_killer).to receive(:enabled?).and_return(true)
      expect(memory_killer).to receive(:any_jobs?).and_return(false)

      expect(memory_killer).not_to receive(:sleep)

      subject
    end

    it 'send signal and wait till deadline if any job not finished' do
      expect(Process).to receive(:kill).with(signal, pid).ordered
      expect(Time).to receive(:now).and_call_original.at_least(:once)

      expect(memory_killer).to receive(:enabled?).and_return(true).at_least(:once)
      expect(memory_killer).to receive(:any_jobs?).and_return(true).at_least(:once)

      expect(memory_killer).to receive(:sleep).and_call_original.exactly(4).times

      subject
    end
  end

  describe '#signal_pgroup' do
    subject { memory_killer.send(:signal_pgroup, time, signal, explanation) }

    let(:time) { 2 }
    let(:signal) { 'my-signal' }
    let(:explanation) { 'my-explanation' }

    it 'call signal_and_wait if it is not group leader' do
      expect(Process).to receive(:getpgrp).and_return(pid + 1)

      expect(memory_killer).to receive(:signal_and_wait)
      expect(Process).not_to receive(:kill)

      subject
    end

    it 'send signal signal to whole process group as group leader' do
      expect(Process).to receive(:getpgrp).and_return(pid)

      expect(memory_killer).not_to receive(:signal_and_wait)
      expect(memory_killer).to receive(:sleep).with(time).ordered
      expect(Process).to receive(:kill).with(signal, 0).ordered

      subject
    end
  end

  describe '#rss_increase_by_jobs' do
    subject { memory_killer.send(:rss_increase_by_jobs) }

    let(:running_jobs) { { id1: 'job1', id2: 'job2' } }

    it 'adds up individual rss_increase_by_job' do
      expect(Gitlab::SidekiqMonitor).to receive_message_chain(:instance, :jobs).and_return(running_jobs)
      expect(memory_killer).to receive(:rss_increase_by_job).and_return(11, 22)
      expect(subject).to eq(33)
    end

    it 'return 0 if no job' do
      expect(Gitlab::SidekiqMonitor).to receive_message_chain(:instance, :jobs).and_return({})
      expect(subject).to eq(0)
    end
  end

  describe '#rss_increase_by_job' do
    subject { memory_killer.send(:rss_increase_by_job, job) }
    let(:worker_class) { Chaos::SleepWorker }
    let(:job) { { worker_class: worker_class, started_at: 321 } }

    it 'return 0 if job is not whitelisted' do
      expect(worker_class).to receive(:sidekiq_options).and_return({ "retry" => 5 })

      expect(Time).not_to receive(:now)
      expect(subject).to eq(0)
    end

    it 'return right value if job is whitelisted' do
      expect(worker_class).to receive(:sidekiq_options).and_return({ "rss_increase_kb" => 10 })

      expect(Time).to receive(:now).and_return(323)
      expect(subject).to eq(20)
    end
  end
end
