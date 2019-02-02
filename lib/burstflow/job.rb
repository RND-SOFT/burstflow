class Burstflow::Job

  include Burstflow::Model

  define_stored_attributes :id, :workflow_id, :klass, :params, :incoming, :outgoing, :payloads, :output, :error
  define_stored_attributes :enqueued_at, :started_at, :finished_at, :failed_at, :suspended_at, :resumed_at

  SUSPEND = 'suspend'.freeze

  class Error < ::RuntimeError; end

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
    assign_default_values(@workflow.get_job_hash(self.id))
  end

  # def save!
  #   @workflow.with_lock do
  #     @workflow.set_job(self)
  #     @workflow.save!
  #     yield if block_given?
  #   end
  # end

  def self.from_hash(workflow, hash_store)
    hash_store[:klass].constantize.new(workflow, hash_store)
  end

  # execute this code by ActiveJob. You may return Burstflow::Job::SUSPEND to suspend job, or call suspend method
  def perform; end

  # execute this code when resumes after suspending
  def resume(data)
    raise Error.new("Can't perform resume: not resumed") if !resumed?
    set_output(data)
  end

  # store data to be available for next jobs
  def set_output(data)
    self.output = data
  end

  # mark execution as suspended
  def suspend
    raise Error.new("Can't suspend: not running") if !running?
    set_output(SUSPEND)
  end

  def configure
    @workflow.with_lock do
      yield
      @workflow.resolve_dependencies
      @workflow.save!
      @workflow.all_jobs.to_a.each(&:save!)
      reload
    end
  end

  def run(klass, opts = {})
    opts[:after] = [*opts[:after], self.id].uniq
    opts[:before] = [*opts[:before], *self.outgoing].uniq
    @workflow.run(klass, opts)
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
    raise Error.new("Can't enqueue: already enqueued") if enqueued?
    self.enqueued_at = current_timestamp
    self.started_at = nil
    self.finished_at = nil
    self.failed_at = nil
    self.suspended_at = nil
    self.resumed_at = nil
  end

  # mark job as started when it is start performing
  def start!
    raise Error.new("Can't start: already started") if started?
    raise Error.new("Can't start: not enqueued") if !enqueued?
    self.started_at = current_timestamp
  end

  # mark job as finished when it is finish performing
  def finish!
    raise Error.new("Can't finish: already finished") if finished?
    raise Error.new("Can't finish: not started") if !started?
    self.finished_at = current_timestamp
  end

  # mark job as failed when it is failed
  def fail! msg
    #raise Error.new("Can't fail: already failed") if failed?
    #raise Error.new("Can't fail: already finished") if finished?
    raise Error.new("Can't fail: not started") if !started?
    self.finished_at = self.failed_at = current_timestamp
    self.error = msg
  end

  # mark job as suspended
  def suspend!
    raise Error.new("Can't suspend: already suspended") if suspended?
    raise Error.new("Can't suspend: not runnig") if !running?
    self.suspended_at = current_timestamp
  end

  # mark job as resumed
  def resume!
    raise Error.new("Can't resume: already resumed") if resumed?
    raise Error.new("Can't resume: not suspended") if !suspended?
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
