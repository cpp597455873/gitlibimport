# frozen_string_literal: true

module Gitlab
  class SidekiqIndependentMemoryKiller < Daemon
    include ::Gitlab::Utils::StrongMemoize # do not know whether we need this?

    # RSS below IDEAL_MAX_RSS is guaranteed to be safe
    IDEAL_MAX_RSS = (ENV['SIDEKIQ_MEMORY_KILLER_IDEAL_MAX_RSS'] || 0).to_i
    # RSS above HARD_LIMIT_MAX_RSS will be killed immediately
    HARD_LIMIT_MAX_RSS = (ENV['SIDEKIQ_MEMORY_KILLER_HARD_LIMIT_MAX_RSS'] || 0).to_i
    # RSS in range (IDEAL_MAX_RSS, HARD_LIMIT_MAX_RSS) will be allowed for ALLOW_RSS_BALLOON_TIME seconds
    # Sidekiq process will be kill if RSS is more than IDEAL_MAX_RSS for longer time than ALLOW_RSS_BALLOON_TIME
    ALLOW_RSS_BALLOON_SECONDS = (ENV['SIDEKIQ_MEMORY_KILLER_ALLOW_RSS_BALLOON_SECONDS'] || 15 * 60).to_i
    # Check RSS every CHECK_INTERVAL_SECONDS
    CHECK_INTERVAL_SECONDS = (ENV['SIDEKIQ_MEMORY_KILLER_CHECK_INTERVAL_SECONDS'] || 3).to_i
    # Wait 30 seconds for running jobs to finish during graceful shutdown
    SHUTDOWN_WAIT = (ENV['SIDEKIQ_MEMORY_KILLER_SHUTDOWN_WAIT'] || 30).to_i
    # Whitelist these jobs from RSS contribution
    # todo: statistic the better value. Maybe staging server is a good test environment?
    # The value 50 means: contribute 50K rss increase per second. This is estimated from: 15M RSS increase when import running for 300 seconds.
    WHILTELIST_JOBS = {
      'RepositoryImportWorker' => { 'rss_time_factor' => 50 },
      'Gitlab::GithubImport::Stage::ImportRepositoryWorker' => { 'rss_time_factor' => 50 },
      'Gitlab::GithubImport::Stage::FinishImportWorker' => { 'rss_time_factor' => 50 }
    }.freeze

    attr_reader :rss_balloon_started_at

    def initialize
      super

      @enabled = true
      reset_rss_balloon_started_time
    end

    private

    attr_writer :rss_balloon_started_at

    def reset_rss_balloon_started_time
      self.rss_balloon_started_at = nil
    end

    def start_working
      Sidekiq.logger.info(
        class: self.class.to_s,
        action: 'start',
        message: "Starting SidekiqIndependentMemoryKiller Daemon. pid: #{pid}"
      )

      while enabled?
        check_rss
        sleep(CHECK_INTERVAL_SECONDS)
      end
    rescue StandardError => e
      Sidekiq.logger.warn( e.message )
    end

    def stop_working
      Sidekiq.logger.info(
        class: self.class.to_s,
        action: 'stop',
        message: 'Stopping SidekiqIndependentMemoryKiller Daemon'
      )

      @enabled = false
    end

    def enabled?
      @enabled
    end

    def check_rss
      Sidekiq.logger.info(
        class: self.class.to_s,
        action: 'check_rss',
        message: "Checking RSS for Sidekiq worker pid(#{pid}"
      )

      current_rss = get_rss
      current_rss_exclude_whitelist = current_rss - whitelist_jobs_rss_contribution
      Sidekiq.logger.info(
        class: self.class.to_s,
        action: 'check_rss',
        message: "current_rss: #{current_rss},  current_rss_exclude_whitelist: #{current_rss_exclude_whitelist}"
      )

      if HARD_LIMIT_MAX_RSS > 0 && current_rss > HARD_LIMIT_MAX_RSS
        hard_limit_kill(current_rss)
      elsif IDEAL_MAX_RSS > 0
        check_balloon_limit_kill(current_rss_exclude_whitelist)
      end
    end

    def check_balloon_limit_kill(current_rss_exclude_whitelist)
      if current_rss_exclude_whitelist < IDEAL_MAX_RSS
        reset_rss_balloon_started_time
        return
      end

      now = Time.now.to_i
      if rss_balloon_started_at.nil?
        self.rss_balloon_started_at = now
      end

      balloon_seconds = now - rss_balloon_started_at

      if balloon_seconds < ALLOW_RSS_BALLOON_SECONDS
        Sidekiq.logger.warn(
          class: self.class.to_s,
          message: "Sidekiq worker PID-#{pid}"\
          " current RSS exclude whitelist #{current_rss_exclude_whitelist}"\
          " exceeds IDEAL_MAX_RSS #{IDEAL_MAX_RSS}"\
          " but balloon_seconds #{balloon_seconds}"\
          " is shorter than ALLOW_RSS_BALLOON_SECONDS #{ALLOW_RSS_BALLOON_SECONDS}"
        ) # todo: we may not need to log every check
      elsif balloon_seconds > ALLOW_RSS_BALLOON_SECONDS
        Sidekiq.logger.warn(
          class: self.class.to_s,
          message: "Sidekiq worker PID-#{pid}"\
          " current RSS #{current_rss_exclude_whitelist}"\
          " exceeds IDEAL_MAX_RSS #{IDEAL_MAX_RSS}"\
          " and balloon_seconds #{balloon_seconds}"\
          " is longer than ALLOW_RSS_BALLOON_SECONDS #{ALLOW_RSS_BALLOON_SECONDS}"
        )

        # wait_and_signal(SHUTDOWN_WAIT, 'SIGTERM', 'gracefully shut down') # should we use SIGKILL?
        wait_and_signal(SHUTDOWN_WAIT, 'SIGKILL', 'forced shut down')

        reset_rss_balloon_started_time
      end
    end

    def hard_limit_kill(current_rss)
      if current_rss > HARD_LIMIT_MAX_RSS
        Sidekiq.logger.warn(
          class: self.class.to_s,
          message: "Sidekiq worker PID-#{pid} current RSS #{current_rss}"\
               " exceeds HARD_LIMIT_MAX_RSS #{HARD_LIMIT_MAX_RSS}"
        )

        # SIGKILL to kill process immediately to avoid Linux OOM
        wait_and_signal(0, 'SIGKILL', 'Terminate immediately')
      end
    end

    def get_rss
      output, status = Gitlab::Popen.popen(%W(ps -o rss= -p #{pid}), Rails.root.to_s)
      return 0 unless status.zero?

      output.to_i
    end

    def wait_and_signal(time, signal, explanation)
      Sidekiq.logger.warn("waiting #{time} seconds before sending Sidekiq worker PID-#{pid} #{signal} (#{explanation})")
      sleep(time)

      Sidekiq.logger.warn("sending Sidekiq worker PID-#{pid} #{signal} (#{explanation})")
      Process.kill(signal, pid)
    end

    def whitelist_jobs_rss_contribution
      running_jobs = Gitlab::SidekiqMonitor.instance.jobs

      debug_whitelist_job = {}
      result = 0
      running_jobs.each do |jid, job|
        result += rss_contribution(job)
        debug_whitelist_job[jid] = job if rss_contribution(job) > 0
      end

      Sidekiq.logger.info("running_jobs: #{running_jobs}")
      Sidekiq.logger.info("debug_whitelist_job: #{debug_whitelist_job}")
      Sidekiq.logger.info("whitelist_jobs_rss_contribution: #{result}")

      result
    end

    def rss_contribution(job)
      worker_class_name = job[:worker_class].name
      return 0 if WHILTELIST_JOBS[worker_class_name].nil?

      time_elapsed = Time.now.to_i - job[:started_at]
      rss_time_factor = WHILTELIST_JOBS[worker_class_name]['rss_time_factor']

      Sidekiq.logger.info("time_elapsed: #{time_elapsed}")
      Sidekiq.logger.info("rss_time_factor: #{rss_time_factor}")

      rss_time_factor * time_elapsed
    end

    def pid
      Process.pid
    end
  end
end
