class Burstflow::Manager

  attr_accessor :workflow

  def initialize(workflow)
    @workflow = workflow
  end

  #workflow management

  def start_workflow!
    workflow.with_lock do
      workflow.mark_runnig
      workflow.save!

      workflow.initial_jobs.each do |job|
        enqueue_job!(job)
      end
    end
  end

  def resume_workflow! job_id, data
    workflow.with_lock do
      workflow.mark_resumed
      workflow.save!

      job = workflow.job(job_id)
      resume_job!(job, data)
    end
  end


  #job management

  def save_job!(job)
    workflow.with_lock do
      workflow.set_job(job)
      workflow.save!
      yield(workflow, job) if block_given?
    end
  end

  #Mark job enqueued and enqueue it
  def enqueue_job!(job)
    job.enqueue!
    save_job!(job) do
      Burstflow::Worker.perform_later(workflow.id, job.id)
    end
  end

  #Enqueue job for resuming
  def resume_job!(job, data)
    Burstflow.logger.debug "[Burstflow] #{job.class}[#{job.id}] resumed"
    save_job!(job) do
      Burstflow::Worker.perform_later(workflow.id, job.id, data)
    end
  end


  #Mark job suspended and forget it until resume
  def suspend_job!(job)
    Burstflow.logger.debug "[Burstflow] #{job.class}[#{job.id}] suspended"
    job.suspend!
    save_job!(job) do
      job_finished(job)
    end
  end


  #Mark job finished and make further actions 
  def finish_job!(job)
    Burstflow.logger.debug "[Burstflow] finished"
    job.finish!
    save_job!(job) do
      job_finished(job)
    end
  end

  #Mark job failed and make further actions 
  def fail_job!(job, message)
    Burstflow.logger.error "[Burstflow] failed: #{message}"
    job.fail! message
    Burstflow.logger.error "[Burstflow] failed marked"
    save_job!(job) do
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
  rescue => e
    Burstflow.logger.debug "[Burstflow] Workflow[#{workflow.id}] job_performed! failure: #{e.message}"
    workflow.add_error(e.message)
    workflow.save!
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

    if job.succeeded? && job.outgoing.any?
      return enqueue_outgoing_jobs(job)
    else
      #job suspended or finished without outgoing jobs
      return workflow_try_finish
    end
  end

  def workflow_finished_or_suspended
    if workflow.has_errors?
      workflow.mark_failed
    elsif workflow.has_suspended_jobs?
      workflow.mark_suspended
    else
      workflow.mark_finished
    end
  end

  #try finish workflow or skip untill jobs runnig
  def workflow_try_finish
    if workflow.has_scheduled_jobs?
      #do nothing
      #scheduled jobs will perform finish action
    else
      workflow_finished_or_suspended
    end

    workflow.save!
  end

  #enqueue outgoing jobs if all requirements are met
  def enqueue_outgoing_jobs(job)
    job.outgoing.each do |job_id|
      out = workflow.job(job_id)

      enqueue_job!(out) if out.ready_to_start?
    end
  end

end
