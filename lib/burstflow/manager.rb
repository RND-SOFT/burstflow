class Burstflow::Manager

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

  #Mark job enqueued and enqueue it
  def enqueue_job!(job)
    job.enqueue!
    job.save! do
      Burstflow::Worker.perform_later(workflow.id, job.id)
    end
  end

  #Mark job resumed and enqueue it
  def resume_job!(job, data)
    job.resume!
    job.save! do
      Burstflow::Worker.perform_later(workflow.id, job.id, data)
    end
  end

  #Mark job started and perform it
  def perform_job!(job)
    job.start!
    job.save!

    job.perform
  end

  #Perform job resuming
  def perform_resume_job!(job, data)
    job.resume(data)
  end

  #Mark job suspended and forget it until resume
  def suspend_job!(job)
    job.suspend!
    job.save!
  end


  #Mark job finished and make further actions 
  def finish_job!(job)
    job.finish!
    job.save! do
      job_finished(job)
    end
  end

  #Mark job failed and make further actions 
  def fail_job!(job)
    job.fail!
    job.save! do
      job_finished(job)
    end
  end

  #Mark job finished or suspended depends on result or output
  def job_performed!(job, result)
    if result == Burstflow::Job::SUSPEND || job.output == Burstflow::Job::SUSPEND
      suspend_job!(job)
    else
      finish_job!(job)
    end
  end

private

  #analyze job completition, current workflow state and perform futher actions
  def job_finished job
    if job.failed?
      workflow.add_error(job)
      return workflow_try_finish
    end

    if workflow.has_errors?
      return workflow_try_finish
    end

    if job.has_outgoing_jobs?
      return enqueue_outgoing_jobs(job)
    else
      return workflow_try_finish
    end
  end

  def workflow_finished
    if workflow.has_errors?
      workflow.fail!
    else
      workflow.finish!
    end
  end

  #try finish workflow or skip untill jobs runnig
  def workflow_try_finish
    if workflow.has_running_jobs?
      #do nothing
      #running jobs will perform finish action
    else
      workflow_finished
    end
  end

  #enqueue outgoing jobs if all requirements are met
  def enqueue_outgoing_jobs(job)
    job.outgoing.each do |job_id|
      out = workflow.get_job(job_id)

      enqueue_job!(out) if out.ready_to_start?
    end
  end

end

class Burstflow::Manager







end

def status
  if failed?
    FAILED
  elsif suspended?
    SUSPENDED
  elsif running?
    RUNNING
  elsif finished?
    FINISHED
  else
    INITIAL
  end
end