class Burst::Job
  include Burst::Model

  define_stored_attributes :id, :workflow_id, :klass, :params, :incoming, :outgoing, :payloads, :output
  define_stored_attributes :enqueued_at, :started_at, :finished_at, :failed_at, :suspended_at, :continued_at

  SUSPEND = 'suspend'

  class Error < ::RuntimeError; end

  def initialize workflow, hash_store = {}
    @workflow = workflow
    assign_default_values(hash_store)
  end

  def assign_default_values hash_store
    set_model(hash_store.deep_dup)

    self.id ||= SecureRandom.uuid
    self.workflow_id ||= @workflow.id
    self.klass ||= self.class.to_s
    self.incoming ||= []
    self.outgoing ||= []
  end

  def reload
    assign_default_values(@workflow.get_job_hash(self.id))
  end

  def save! &block
    @workflow.with_lock do
      @workflow.set_job(self)
      @workflow.save! 
      yield if block_given?
    end
  end

  def self.from_hash workflow, hash_store
    hash_store[:klass].constantize.new(workflow, hash_store)
  end

  #execute this code by ActiveJob. You may return Burst::Job::SUSPEND to suspend job, or call suspend method
  def perform
  end

  #execute this code when ressurected after suspending
  def continue data
    set_output(data)
  end

  #store data to be available for next jobs
  def set_output data
    self.output = data
  end

  #mark execution as suspended
  def suspend
    set_output(SUSPEND)
  end

  def attributes
    {
      workflow_id: self.workflow_id,
      id: self.id,
      klass: self.klass,
      params: self.params,
      incoming: self.incoming,
      outgoing: self.outgoing,
      output: self.output,
      started_at: self.started_at,
      enqueued_at: self.enqueued_at,
      finished_at: self.finished_at,      
      failed_at: self.failed_at,
      suspended_at: self.suspended_at,
      continued_at: self.continued_at,
    }
  end


  #mark job as enqueued when it is scheduled to queue
  def enqueue!
    raise Error.new("Already enqueued") if enqueued?
    self.enqueued_at = current_timestamp
    self.started_at = nil
    self.finished_at = nil
    self.failed_at = nil
    self.suspended_at = nil
    self.continued_at = nil
  end

  #mark job as started when it is start performing
  def start!
    raise Error.new("Already started") if started?
    self.started_at = current_timestamp
  end

  #mark job as finished when it is finish performing
  def finish!
    raise Error.new("Already finished") if finished?
    self.finished_at = current_timestamp
  end

  #mark job as failed when it is failed
  def fail!
    raise Error.new("Already failed") if failed?
    self.finished_at = failed_at = current_timestamp
  end

  #mark job as suspended
  def suspend!
    self.suspended_at = current_timestamp
  end

  #mark job as continue
  def continue!
    raise Error.new("Not suspended ") if !suspended?
    raise Error.new("Already continued ") if continued?
    self.continued_at = current_timestamp
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

  def failed?
    !failed_at.nil?
  end

  def suspended?
    !suspended_at.nil? && !continued?
  end

  def continued?
    !continued_at.nil?
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
      @workflow.get_job(id).succeeded?
    end
  end


end