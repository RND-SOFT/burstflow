class Burst::Manager
  attr_accessor :workflow

  def initialize workflow
    @workflow = workflow
  end

  def start
    workflow.with_lock do
      workflow.initial_jobs.each do |job|
        enqueue_job(job)
      end
    end
  end

  def enqueue_job job
    job.enqueue!
    job.save! do
      Burst::Worker.perform_later(workflow.id, job.id)
    end
  end

  def ressurect job, data
    job.ressurect!
    job.save! do
      Burst::Worker.perform_later(workflow.id, job.id, data)
    end
  end

  def mark_as_started job
    job.start!
    job.save!
  end

  def mark_as_suspended job
    job.suspend!
    job.save!
  end

  def mark_as_finished job
    job.finish!
    job.save!

    workflow.with_lock do
      enqueue_outgoing_jobs(job)
    end
  end

  def mark_as_failed job
    job.fail!
    job.save!
  end

  def enqueue_outgoing_jobs job
    job.outgoing.each do |job_id|
      out = workflow.get_job(job_id)

      if out.ready_to_start?
        enqueue_job(out)
      end
    end
  end

end