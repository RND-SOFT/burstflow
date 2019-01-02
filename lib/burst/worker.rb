class Burst::Worker < ::ActiveJob::Base

  def perform(workflow_id, job_id, ressurect_data = nil)
    setup(workflow_id, job_id)

    job.payloads = incoming_payloads

    result = if ressurect_data.nil?
      @manager.mark_as_started(job)
      job.perform
    else
      job.perform_ressurect(ressurect_data)
    end

    if result == Burst::Job::SUSPEND || job.output == Burst::Job::SUSPEND
      @manager.mark_as_suspended(job)
    else
      @manager.mark_as_finished(job)
    end

  rescue StandardError => e
    @manager.mark_as_failed(job)
    raise e
  end


private

  attr_reader :workflow, :job

  def setup(workflow_id, job_id)
    @workflow = Burst::Workflow.find(workflow_id)
    @job = @workflow.get_job(job_id)
    @manager = Burst::Manager.new(@workflow)
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