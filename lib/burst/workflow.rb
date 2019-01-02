class Burst::Workflow < ActiveRecord::Base
  self.table_name_prefix = 'burst_'

  INITIAL   = 'initial'
  RUNNING   = 'running'
  FINISHED  = 'finished'
  FAILED    = 'failed'
  SUSPENDED = 'suspended'

  include Burst::WorkflowHelper
  include Burst::Builder
  
  attr_accessor :manager, :job_cache
  define_flow_attributes :jobs, :klass

  after_initialize  do
    initialize_builder()

    @job_cache = {}

    self.id ||= SecureRandom.uuid
    self.jobs ||= {}.with_indifferent_access
    self.klass ||= self.class.to_s

    @manager = Burst::Manager.new(self)
  end

  def attributes
    {
      id: self.id,
      jobs: self.jobs,
      klass: self.klass,
      status: self.status
    }
  end

  def self.build *args
    wf = self.new()
    wf.configure(*args)
    wf.resolve_dependencies
    wf
  end

  def reload options = nil
    self.job_cache = {}
    super
  end

  def start!
    save!
    manager.start
  end

  def resume! job_id, data
    manager.resume!(get_job(job_id), data)
  end

  def status
    case
      when failed?
        FAILED
      when suspended?
        SUSPENDED
      when running?
        RUNNING
      when finished?
        FINISHED
      else
        INITIAL
    end
  end

  def initial?
    self.status == INITIAL
  end

  def finished?
    all_jobs.all?(&:finished?)
  end

  def started?
    !!started_at
  end

  def running?
    started? && !finished?
  end

  def failed?
    all_jobs.any?(&:failed?)
  end

  def suspended?
    !failed? && all_jobs.any?(&:suspended?)
  end

  def all_jobs
    Enumerator.new do |y|
      jobs.keys.each do |id|
        y << get_job(id)
      end
    end
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



  def set_job job
    jobs[job.id] = job.as_json
  end

  def initial_jobs
    all_jobs.select(&:initial?)
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

private

  def find_id_by_klass klass
    finded = jobs.select do |_, job|
      job[:klass].to_s == klass.to_s
    end

    raise "Duplicat job detected" if finded.count > 1
    return finded.first.second[:id]
  end

end
