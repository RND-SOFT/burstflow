class Burst::Workflow
  include Burst::Model
  include Burst::Builder

  define_stored_attributes :id, :jobs, :klass

  attr_accessor :store, :job_cache

  def initialize store
    initialize_builder()

    @store = store
    @job_cache = {}

    assign_default_values(@store.flow)
  end


  def assign_default_values hash_store
    set_model(hash_store)

    self.id = @store.id
    self.jobs ||= {}.with_indifferent_access
    self.klass ||= self.class.to_s
  end


  def attributes
    {
      id: self.id,
      jobs: self.jobs,
      klass: self.klass,
    }
  end

  def self.build *args
    wf = self.new(Burst::Store.new)
    wf.configure(*args)
    wf.resolve_dependencies
    wf.build_jobs.each do |job|
      wf.jobs[job.id] = job.as_json
    end

    wf
  end

  def self.create! *args
    wf = self.build(*args)
    wf.save!
  end

  def self.find id
    self.new(Burst::Store.find(id))
  end


  def save!
    store.save!
    self
  end

  def reload
    self.store.reload
    self.job_cache = {}
    assign_default_values(self.store.flow)
  end

  def with_lock &block
    store.with_lock do
      self.job_cache = {}
      assign_default_values(self.store.flow)
      yield
    end
  end

  def start!
    Burst::Manager.new(self).start
  end

  def ressurect! job_id, data
    Burst::Manager.new(self).ressurect(get_job(job_id), data)
  end

  def status
    case
      when failed?
        :failed
      when suspended?
        :suspended
      when running?
        :running
      when finished?
        :finished
      else
        :initial
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

  def suspended?
    each_job.any?(&:suspended?)
  end


  def get_job id
    if job = @job_cache[id]
      return job
    else
      job = Burst::Job.from_hash(self, jobs[id].deep_dup)
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

  def get_job_hash id
    jobs[id]
  end

  def configure *args
  end

  def started_at
    first_job&.started_at
  end

  def finished_at
    last_job&.finished_at
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
