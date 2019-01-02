class Burst::Worker < ::ActiveJob::Base

  def perform(workflow_id, job_id, resume_data = nil)
    setup(workflow_id, job_id)

    job.payloads = incoming_payloads

    result = if resume_data.nil?
               @manager.start_job!(job)
             else
               @manager.resume_job!(job, resume_data)
    end

    @manager.job_performed!(job, result)
  rescue StandardError => e
    @manager.fail_job!(job)
    raise e
  end


  private

    attr_reader :workflow, :job

    def setup(workflow_id, job_id)
      @workflow = Burst::Workflow.find(workflow_id)
      @job = @workflow.get_job(job_id)
      @manager = @workflow.manager
    end

    def incoming_payloads
      job.incoming.map do |job_id|
        incoming = workflow.get_job(job_id)
        {
          id: incoming.id,
          class: incoming.klass.to_s,
          payload: incoming.output
        }
      end
    end

end
