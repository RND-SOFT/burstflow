require 'active_record'

require 'burstflow/manager'

module Burstflow

  class Workflow < ActiveRecord::Base

    require 'burstflow/workflow/exception'
    require 'burstflow/workflow/builder'
    require 'burstflow/workflow/configuration'
    require 'burstflow/workflow/callbacks'

    self.table_name_prefix = 'burstflow_'

    INITIAL   = 'initial'.freeze
    RUNNING   = 'running'.freeze
    SUCCEEDED = 'succeeded'.freeze
    FAILED    = 'failed'.freeze
    CANCELLED = 'cancelled'.freeze
    SUSPENDED = 'suspended'.freeze

    STATUSES = [INITIAL, RUNNING, SUCCEEDED, FAILED, CANCELLED, SUSPENDED].freeze
    FINISHED = [SUCCEEDED, FAILED, CANCELLED].freeze

    include Burstflow::Workflow::Configuration
    include Burstflow::Workflow::Callbacks

    attr_accessor :manager, :cache
    define_flow_attributes :jobs_config, :failures

    validates :id, uniqueness: { case_sensitive: false }
    validates :status, inclusion: { in: STATUSES }

    validate  :persistance_of_running

    scope :same, ->(w) {
      if w.identifier
        w.class.where(status: [RUNNING, SUSPENDED], identifier: w.identifier)
      else
        w.class.where(status: [RUNNING, SUSPENDED])
      end
    }

    after_initialize do
      @cache = {}

      self.status ||= INITIAL
      self.id ||= SecureRandom.uuid
      self.jobs_config ||= {}.with_indifferent_access
      self.failures ||= []

      @manager = Burstflow::Manager.new(self)
    end

    STATUSES.each do |name|
      define_method "#{name}?".to_sym do
        self.status == name
      end
    end

    def finished?
      FINISHED.include?(status)
    end

    def allow_to_start?
      if singleton?
        !self.class.same(self).any?
      else
        true
      end
    end

    def attributes
      {
        id: self.id,
        identifier: self.identifier,
        jobs_config: self.jobs_config,
        type: self.class.to_s,
        status: status,
        failures: failures
      }
    end

    def self.build(*args)
      new.tap do |wf|
        builder = Burstflow::Workflow::Builder.new(wf, *args, &configuration)
        wf.identifier = builder.identifier
        wf.flow = { 'jobs_config' => builder.as_json }
      end
    end

    def reload(*)
      self.cache = {}
      super
    end

    def start!
      manager.start_workflow!
      self
    end

    def resume!(job_id, data)
      manager.resume_workflow!(job_id, data)
      self
    end

    def jobs
      Enumerator.new do |y|
        jobs_config.keys.each do |id|
          y << job(id)
        end
      end
    end

    def job_hash(id)
      jobs_config[id].deep_dup
    end

    def job(id)
      Burstflow::Job.from_hash(self, job_hash(id))
    end

    def set_job(job)
      jobs_config[job.id] = job.as_json
    end

    def initial_jobs
      cache[:initial_jobs] ||= jobs.select(&:initial?)
    end

    def add_error(job_orexception)
      context = {
        created_at: Time.now.to_i
      }
      if job_orexception.is_a?(::Exception)
        context[:message]     = job_orexception.message
        context[:klass]       = job_orexception.class.to_s
        context[:backtrace]   = job_orexception.backtrace.first(10)
        context[:cause]       = job_orexception.cause
      else
        context[:job] = job_orexception.id
      end

      failures.push(context)
    end

    def has_errors?
      failures.any?
    end

    def has_scheduled_jobs?
      cache[:has_scheduled_jobs] ||= jobs.any? do |job|
        job.scheduled? || (job.initial? && !job.enqueued?)
      end
    end

    def has_suspended_jobs?
      cache[:has_suspended_jobs] ||= jobs.any?(&:suspended?)
    end

    def complete!
      if has_errors?
        #TODO test errors in failed! or callbacks
        failed!
      elsif has_suspended_jobs?
        suspended!
      else
        succeeded!
      end
    end

    def first_job
      all_jobs.min_by{|n| n.started_at || Time.now.to_i }
    end

    def last_job
      all_jobs.max_by{|n| n.finished_at || 0 } if finished?
    end

    def started_at
      first_job&.started_at
    end

    def finished_at
      last_job&.finished_at
    end

    def running!
      raise InternalError.new(self, "Can't start: workflow already running") if running? || suspended?
      raise InternalError.new(self, "Can't start: workflow already finished") if finished?

      self.status = RUNNING
      save!
    end

    def failed!
      raise InternalError.new(self, "Can't fail: workflow already finished") if finished?
      raise InternalError.new(self, "Can't fail: workflow in not running") unless running? || suspended?

      run_callbacks :failed do
        self.status = FAILED
        run_callbacks :finished do
          save!
        end
      end
    end

    def succeeded!
      raise InternalError.new(self, "Can't finish: workflow already finished") if finished?
      raise InternalError.new(self, "Can't finish: workflow in not running") unless running?

      run_callbacks :succeeded do
        self.status = SUCCEEDED
        run_callbacks :finished do
          save!
        end
      end
    end

    def suspended!
      raise InternalError.new(self, "Can't suspend: workflow already finished") if finished?
      raise InternalError.new(self, "Can't suspend: workflow in not running") unless running?

      run_callbacks :suspend do
        self.status = SUSPENDED
        run_callbacks :finished do
          save!
        end
      end
    end

    def resumed!
      raise InternalError.new(self, "Can't resume: workflow already running") if running?
      raise InternalError.new(self, "Can't resume: workflow already finished") if finished?
      raise InternalError.new(self, "Can't resume: workflow in not suspended") unless suspended?

      self.status = RUNNING
      save!
    end

    def cancelled!
      raise InternalError.new(self, "Can't cancell workflow already finished") if finished?

      run_callbacks :cancelled do
        self.status = CANCELLED
        save!
      end
    end

    def persistance_of_running
      if singleton? && !allow_to_start?
        if identifier
          errors.add(:workflow, "with such identifier is still being running")
        else
          errors.add(:workflow, "with such type is still being running")
        end
      end
    end

  end

end
