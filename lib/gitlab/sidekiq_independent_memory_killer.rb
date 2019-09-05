# frozen_string_literal: true

module Gitlab
  class SidekiqIndependentMemoryKiller < Daemon
    include ::Gitlab::Utils::StrongMemoize

    # 64-bit CPU support max 256T memory in theory
    MAX_MEMORY = 256 * 1024 * 1024 * 1024
    # RSS below `soft_limit_rss` is considered safe
    SOFT_LIMIT_RSS = (ENV['SIDEKIQ_MEMORY_SOFT_LIMIT_RSS'] || MAX_MEMORY).to_i
    # RSS above HARD_LIMIT_RSS will be stopped
    HARD_LIMIT_RSS = (ENV['SIDEKIQ_MEMORY_KILLER_HARD_LIMIT_RSS'] || MAX_MEMORY).to_i
    # RSS in range (soft_limit_rss, hard_limit_rss) is allowed for GRACE_BALLOON_SECONDS
    GRACE_BALLOON_SECONDS = (ENV['SIDEKIQ_MEMORY_KILLER_GRACE_BALLOON_SECONDS'] || 15 * 60).to_i
    # Check RSS every CHECK_INTERVAL_SECONDS
    CHECK_INTERVAL_SECONDS = (ENV['SIDEKIQ_MEMORY_KILLER_CHECK_INTERVAL_SECONDS'] || 3).to_i
    # Give Sidekiq 15 minutes of grace time after exceeding the RSS limit
    GRACE_TIME = (ENV['SIDEKIQ_MEMORY_KILLER_GRACE_TIME'] || 15 * 60).to_i
    # Wait 30 seconds for running jobs to finish during graceful shutdown
    SHUTDOWN_WAIT = (ENV['SIDEKIQ_MEMORY_KILLER_SHUTDOWN_WAIT'] || 30).to_i

    def initialize
      super

      @enabled = true
    end

    private

    def start_working
      Sidekiq.logger.info(
        class: self.class.to_s,
        action: 'start',
        message: "Starting SidekiqIndependentMemoryKiller Daemon. pid: #{pid}"
      )

      while enabled?
        begin
          check_rss
          sleep(CHECK_INTERVAL_SECONDS)
        rescue StandardError => e
          Sidekiq.logger.warn("Error from #{self.class}##{__method__}: #{e.message}")
        end
      end
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
        message: "Checking RSS for Sidekiq worker pid(#{pid}) current_rss(#{current_rss})"
      )

      # everything is within limit
      return if current_rss < soft_limit_rss && current_rss < hard_limit_rss

      deadline = Time.now.to_i + GRACE_BALLOON_SECONDS
      # we try to finish as early as all jobs finished, so we retest that in loop
      while enabled? && any_jobs? && Time.now.to_i < deadline
        # RSS go above hard limit and triggers forcible shutdown right away
        break if current_rss > hard_limit_rss

        # RSS go below the limit
        return if current_rss < soft_limit_rss

        sleep(CHECK_INTERVAL) # do we want to check more frequently, such as 500ms?
      end

      # Then, tell Sidekiq to stop fetching new jobs.
      # We first SIGNAL and then wait given time
      # We also monitor a number of running jobs and allow to restart early
      signal_and_wait(GRACE_TIME, 'SIGTSTP', 'stop fetching new jobs')
      return unless enabled?

      # Tell sidekiq to restart itself
      signal_and_wait(SHUTDOWN_WAIT, 'SIGTERM', 'gracefully shut down')
      return unless enabled?

      # Ideally we should never reach this condition
      # Wait for Sidekiq to shutdown gracefully, and kill it if it didn't.
      # Kill the whole pgroup, so we can be sure no children are left behind
      signal_pgroup(Sidekiq.options[:timeout] + 2, 'SIGKILL', 'die')
    end

    def current_rss
      output, status = Gitlab::Popen.popen(%W(ps -o rss= -p #{pid}), Rails.root.to_s)
      return 0 unless status.zero?

      output.to_i
    end

    def soft_limit_rss
      SOFT_LIMIT_RSS + rss_increase_by_jobs
    end

    def hard_limit_rss
      HARD_LIMIT_RSS
    end

    def signal_and_wait(time, signal, explanation)
      Sidekiq.logger.warn("sending Sidekiq worker PID-#{pid} #{signal} (#{explanation}). Then wait at most #{time} seconds.")
      Process.kill(signal, Process.pid)

      deadline = Time.now + time

      # we try to finish as early as all jobs finished
      # so we retest that in loop
      while enabled? && any_jobs? && Time.now < deadline
        sleep(0.5) # wait 500ms between checks
      end
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
      rss_increase_kb_per_sec = job[:worker_class].sidekiq_options['rss_increase_kb']

      return 0 if rss_increase_kb_per_sec.nil?

      time_elapsed = Time.now.to_i - job[:started_at]

      rss_increase_kb_per_sec * time_elapsed
    end

    def pid
      Process.pid
    end

    def any_jobs?
      Gitlab::SidekiqMonitor.instance.jobs.any?
    end
  end
end
