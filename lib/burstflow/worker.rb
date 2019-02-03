require 'active_job'

class Burstflow::Worker < ::ActiveJob::Base

  attr_reader :workflow, :job

  rescue_from(Exception) do |exception|
    @manager.fail_job!(job, exception)
  end

  rescue_from(Burstflow::Job::InternalError) do |exception|
    @manager.fail_job!(exception.job, exception)
  end

  rescue_from(Burstflow::Workflow::InternalError) do |exception|
    exception.workflow.add_error(exception)
    exception.workflow.save!
  end

  before_perform do
    workflow_id, job_id, resume_data = arguments

    @workflow = Burstflow::Workflow.find(workflow_id)
    @job = @workflow.job(job_id)
    @manager = @workflow.manager

    set_incoming_payloads(job)
  end

  def perform(workflow_id, job_id, resume_data = nil)
    result = if resume_data.nil?
      job.start!
      job.save!
  
      job.perform_now
    else
      job.resume!
      job.save!
      
      job.resume_now(resume_data)
    end

    @manager.job_performed!(job, result)
  end

private

  def set_incoming_payloads job
    job.payloads = job.incoming.map do |job_id|
      incoming = workflow.job(job_id)
      {
        id: incoming.id,
        class: incoming.klass.to_s,
        value: incoming.output
      }
    end
  end

end
