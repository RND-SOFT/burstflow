class Burstflow::Job
  include Burstflow::Model

  attr_accessor :payloads

  define_stored_attributes :id, :workflow_id, :klass, :params, :incoming, :outgoing, :output, :error
  define_stored_attributes :enqueued_at, :started_at, :finished_at, :failed_at, :suspended_at, :resumed_at

  SUSPEND = 'suspend'.freeze

  class InternalError < ::RuntimeError
    attr_accessor :job

    def initialize(job, message)
      @job = job
      super(message)
    end
  end

  def initialize(workflow, hash_store = {})
    @workflow = workflow
    assign_default_values(hash_store)
  end

  def assign_default_values(hash_store)
    set_model(hash_store.deep_dup)

    self.id ||= SecureRandom.uuid
    self.workflow_id ||= @workflow.try(:id)
    self.klass ||= self.class.to_s
    self.incoming ||= []
    self.outgoing ||= []
  end

  def reload
    assign_default_values(@workflow.job_hash(self.id))
  end

  def save!
    @workflow.with_lock do
      @workflow.set_job(self)
      @workflow.save!
      yield if block_given?
    end
  end

  def self.from_hash(workflow, hash_store)
    hash_store[:klass].constantize.new(workflow, hash_store)
  end

  # execute this code by ActiveJob. You may return Burstflow::Job::SUSPEND to suspend job, or call suspend method
  def perform; end

  # execute this code when resumes after suspending
  def resume(data)
    raise InternalError.new(self, "Can't perform resume: not resumed") if !resumed?
    set_output(data)
  end

  # store data to be available for next jobs
  def set_output(data)
    self.output = data
  end

  # mark execution as suspended
  def suspend
    raise InternalError.new(self, "Can't suspend: not running") if !running?
    set_output(SUSPEND)
  end

  def configure *args, &block
    @workflow.with_lock do

      builder = Burstflow::Workflow::Builder.new(@workflow, *args, &block)
      @workflow.flow['jobs_config'] = builder.as_json
      @workflow.save!
      reload
    end
  end

  def attributes
    {
      workflow_id: self.workflow_id,
      id: self.id,
      klass: self.klass,
      params: params,
      incoming: self.incoming,
      outgoing: self.outgoing,
      output: output,
      started_at: started_at,
      enqueued_at: enqueued_at,
      finished_at: finished_at,
      failed_at: failed_at,
      suspended_at: suspended_at,
      resumed_at: resumed_at,
      error: self.error
    }
  end

  # mark job as enqueued when it is scheduled to queue
  def enqueue!
    raise InternalError.new(self, "Can't enqueue: already enqueued") if enqueued?
    self.enqueued_at = current_timestamp
    self.started_at = nil
    self.finished_at = nil
    self.failed_at = nil
    self.suspended_at = nil
    self.resumed_at = nil
  end

  # mark job as started when it is start performing
  def start!
    raise InternalError.new(self, "Can't start: already started") if started?
    raise InternalError.new(self, "Can't start: not enqueued") if !enqueued?
    self.started_at = current_timestamp
  end

  # mark job as finished when it is finish performing
  def finish!
    raise InternalError.new(self, "Can't finish: already finished") if finished?
    raise InternalError.new(self, "Can't finish: not started") if !started?
    self.finished_at = current_timestamp
  end

  # mark job as failed when it is failed
  def fail! msg
    #raise InternalError.new(self, "Can't fail: already failed") if failed?
    #raise InternalError.new(self, Can't fail: already finished") if finished?
    raise InternalError.new(self, "Can't fail: not started") if !started?
    self.finished_at = self.failed_at = current_timestamp
    self.error = msg
  end

  # mark job as suspended
  def suspend!
    raise InternalError.new(self, "Can't suspend: already suspended") if suspended?
    raise InternalError.new(self, "Can't suspend: not runnig") if !running?
    self.suspended_at = current_timestamp
  end

  # mark job as resumed
  def resume!
    raise InternalError.new(self, "Can't resume: already resumed") if resumed?
    raise InternalError.new(self, "Can't resume: not suspended") if !suspended?
    self.resumed_at = current_timestamp
  end

  def enqueued?
    !enqueued_at.nil?
  end

  def started?
    !started_at.nil?
  end

  def finished?
    !finished_at.nil?
  end

  def running?
    started? && !finished? && !suspended?
  end

  def scheduled?
    enqueued? && !finished? && !suspended?
  end

  def failed?
    !failed_at.nil?
  end

  def suspended?
    !suspended_at.nil? && !resumed?
  end

  def resumed?
    !resumed_at.nil?
  end

  def succeeded?
    finished? && !failed?
  end

  def ready_to_start?
    !running? && !enqueued? && !finished? && !failed? && parents_succeeded?
  end

  def initial?
    incoming.empty?
  end

  def current_timestamp
    Time.now.to_i
  end

  def parents_succeeded?
    incoming.all? do |id|
      @workflow.job(id).succeeded?
    end
  end


end
