class Burstflow::Worker < ::ActiveJob::Base

  def perform(workflow_id, job_id, resume_data = nil)
    setup(workflow_id, job_id)

    job.payloads = incoming_payloads

    result = if resume_data.nil?
      perform_job!(job)
    else
      resume_job!(job, resume_data)
    end

    @manager.job_performed!(job, result)
  rescue => e
    @manager.fail_job!(job, e.message)
  end

  def perform_job!(job)
    job.start!
    @manager.save_job!(job)

    job.perform
  end

  def resume_job!(job, data)
    job.resume!
    @manager.save_job!(job)
    
    job.resume(data)
  end

private

  attr_reader :workflow, :job

  def setup(workflow_id, job_id)
    @workflow = Burstflow::Workflow.find(workflow_id)
    @job = @workflow.job(job_id)
    @manager = @workflow.manager
  end

  def incoming_payloads
    job.incoming.map do |job_id|
      incoming = workflow.job(job_id)
      {
        id: incoming.id,
        class: incoming.klass.to_s,
        payload: incoming.output
      }
    end
  end

end
