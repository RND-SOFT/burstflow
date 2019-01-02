class Burst::Manager

  attr_accessor :workflow

  def initialize(workflow)
    @workflow = workflow
  end

  def start
    workflow.with_lock do
      raise 'Already started' unless workflow.initial?

      workflow.initial_jobs.each do |job|
        enqueue_job!(job)
      end
    end
  end

  def enqueue_job!(job)
    job.enqueue!
    job.save! do
      Burst::Worker.perform_later(workflow.id, job.id)
    end
  end

  def resume!(job, data)
    job.resume!
    job.save! do
      Burst::Worker.perform_later(workflow.id, job.id, data)
    end
  end

  def start_job!(job)
    job.start!
    job.save!

    job.perform
  end

  def resume_job!(job, data)
    job.resume(data)
  end

  def suspend_job!(job)
    job.suspend!
    job.save!
  end

  def finish_job!(job)
    job.finish!
    job.save!

    workflow.with_lock do
      enqueue_outgoing_jobs(job)
    end
  end

  def job_performed!(job, result)
    if result == Burst::Job::SUSPEND || job.output == Burst::Job::SUSPEND
      suspend_job!(job)
    else
      finish_job!(job)
    end
  end

  def fail_job!(job)
    job.fail!
    job.save!
  end

  def enqueue_outgoing_jobs(job)
    job.outgoing.each do |job_id|
      out = workflow.get_job(job_id)

      enqueue_job!(out) if out.ready_to_start?
    end
  end

end
