class Burstflow::Workflow < ActiveRecord::Base
  require 'burstflow/workflow/builder'
  require 'burstflow/workflow/configuration'
  
  self.table_name_prefix = 'burstflow_'

  INITIAL   = 'initial'.freeze
  RUNNING   = 'running'.freeze
  FINISHED  = 'finished'.freeze
  FAILED    = 'failed'.freeze
  SUSPENDED = 'suspended'.freeze

  STATUSES = [INITIAL, RUNNING, FINISHED, FAILED, SUSPENDED].freeze

  include Burstflow::Workflow::Configuration
  include Burstflow::WorkflowHelper
  #include Burstflow::Builder

  attr_accessor :manager, :cache
  define_flow_attributes :jobs_config, :failures, :klass

  after_initialize do
    @cache = {}

    self.status ||= INITIAL
    self.id ||= SecureRandom.uuid
    self.jobs_config ||= {}.with_indifferent_access
    self.klass ||= self.class.to_s
    self.failures ||= []

    @manager = Burstflow::Manager.new(self)
  end

  STATUSES.each do |name|
    define_method "#{name}?".to_sym do
      self.status == name
    end
  end

  def attributes
    {
      id: self.id,
      jobs_config: self.jobs_config,
      klass: self.klass,
      status: status,
      failures: failures
    }
  end

  def self.build(*args)
    new.tap do |wf|
      builder = Burstflow::Workflow::Builder.new(wf, *args, &configuration)
      wf.flow = {'jobs_config' => builder.as_json}
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

  def add_error job_or_message, exception = nil
    context = {}
    if exception
      context[:message] = exception.message
      context[:klass] = exception.class.to_s
      context[:backtrace] = exception.backtrace.first(10)
    end

    if job_or_message.is_a? Burstflow::Job
      failures.push(context: context, job: job_or_message.id, msg: job_or_message.error.to_s || 'unknown', created_at: Time.now)
    else
      failures.push(context: context, job: nil, msg: job_or_message.to_s, created_at: Time.now)
    end
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
      failed!
    elsif has_suspended_jobs?
      suspended!
    else
      finished!
    end
  end


  def runnig!
    raise "Can't start: workflow already running" if (running? || suspended?)
    raise "Can't start: workflow already failed" if failed?
    raise "Can't start: workflow already finished" if finished?
    self.status = RUNNING
    save!
  end

  def failed!
    raise "Can't fail: workflow already failed" if failed?
    raise "Can't fail: workflow already finished" if finished?
    raise "Can't fail: workflow in not runnig" if !(running? || suspended?)
    self.status = FAILED
    save!
  end

  def finished!
    raise "Can't finish: workflow already finished" if finished?
    raise "Can't finish: workflow already failed" if failed?
    raise "Can't finish: workflow in not runnig" if !running?
    self.status = FINISHED
    save!
  end

  def suspended!
    raise "Can't suspend: workflow already finished" if finished?
    raise "Can't suspend: workflow already failed" if failed?
    raise "Can't suspend: workflow in not runnig" if !running?
    self.status = SUSPENDED
    save!
  end

  def resumed!
    raise "Can't resume: workflow already running" if running?
    raise "Can't resume: workflow already finished" if finished?
    raise "Can't resume: workflow already failed" if failed?
    raise "Can't resume: workflow in not suspended" if !suspended?
    self.status = RUNNING
    save!
  end

end
