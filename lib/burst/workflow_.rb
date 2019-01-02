class Burst::Workflow
  include ActiveModel::Model
  include ActiveModel::Dirty
  include ActiveModel::Serialization
  extend ActiveModel::Callbacks

  define_model_callbacks :initialize

  attr_accessor :id, :jobs, :stopped, :klass
  attr_accessor :builder, :store, :job_cache

  def self.from_hash hash
    hash = hash.with_indifferent_access
    hash[:jobs] = (hash[:jobs] || {}).with_indifferent_access
    hash[:stopped] = hash[:stopped]

    hash[:klass].constantize.new(hash)
  end

  def self.from_store store
    hash = store.flow.deep_dup || {}
    hash[:store] = store
    hash[:id] = store.id

    self.from_hash(hash)
  end


  def initialize args = {}
    @args = args.with_indifferent_access

    @args[:id] ||= SecureRandom.uuid
    @args[:jobs] ||= {}
    @args[:klass] = self.class.to_s
    @args[:stopped] ||= false

    @job_cache = {}

    run_callbacks :initialize do
      super(@args)
    end
  end

  after_initialize do
    id ||= SecureRandom.uuid
  end

  def self.build *args
    wf = self.new(builder: Burst::Builder.new, store: Burst::Store.new)
    wf.configure(*args)
    wf.builder.resolve_dependencies
    wf.builder.jobs.each do |job|
      wf.jobs[job.id] = job.as_json
    end
    wf
  end

  def self.create! *args
    wf = self.build(*args)
    wf.save!
  end

  def self.find id
    self.from_store(Burst::Store.find(id))
  end

  def as_json *args
    self.serializable_hash
  end

  def save!
    store.assign_attributes id: self.id, flow: self.as_json
    store.save!
    self
  end

  def reload
    self.job_cache = {}
    self.assign_attributes Burst::Workflow.from_store(store).as_json
  end

  def with_lock &block
    store.with_lock do
      self.reload
      yield
    end
  end

  def start!
    manager = Burst::Manager.new(self)
    manager.start
  end

  def status
    case
      when failed?
        :failed
      when running?
        :running
      when finished?
        :finished
      when stopped?
        :stopped
      else
        :running
    end
  end

  def finished?
    each_job.all?(&:finished?)
  end

  def started?
    !!started_at
  end

  def running?
    started? && !finished?
  end

  def failed?
    each_job.any?(&:failed?)
  end

  def stopped?
    stopped
  end


  def get_job id
    if job = @job_cache[id]
      return job
    else
      job = Burst::Job.from_hash(self, jobs[id])
      @job_cache[job.id] = job
      return job
    end
  end

  def each_job &block
    Enumerator.new do |y|
      jobs.keys.each do |id|
        y << get_job(id)
      end
    end
  end

  def set_job job
    jobs[job.id] = job.as_json
  end

  def initial_jobs
    each_job.select(&:initial?)
  end

  def find_job(id_or_klass)
    id = if jobs.keys.include?(id_or_klass)
      id_or_klass
    else
      find_id_by_klass(id_or_klass)
    end

    return get_job(id)
  end

  def configure *args
  end

  def run klass, opts = {}
    builder.add(self, klass, opts)
  end


  def attributes
    {
      id: self.id,
      jobs: self.jobs,
      stopped: self.stopped,
      klass: self.klass
    }
  end

  def started_at
    first_job&.started_at : nil
  end

  def finished_at
    last_job&.finished_at : nil
  end

  def first_job
    each_job.min_by{ |n| n.started_at || Time.now.to_i }
  end

  def last_job
    each_job.max_by{ |n| n.finished_at || 0 } if finished?
  end

private

  def find_id_by_klass klass
    finded = jobs.select do |_, job|
      job[:klass].to_s == klass.to_s
    end

    raise "Duplicat job detected" if finded.count > 1
    return finded.first.second[:id]
  end

end
