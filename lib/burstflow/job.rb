require 'active_support/rescuable'
require 'active_job/callbacks'

class Burstflow::Job

  require 'burstflow/job/exception'
  require 'burstflow/job/model'
  require 'burstflow/job/initialization'
  require 'burstflow/job/state'
  require 'burstflow/job/callbacks'

  include Burstflow::Job::Model
  include Burstflow::Job::Initialization
  include Burstflow::Job::State
  include Burstflow::Job::Callbacks
  include ActiveSupport::Rescuable

  attr_accessor :workflow, :payloads

  define_stored_attributes :id, :workflow_id, :klass, :params, :incoming, :outgoing, :output, :failure
  define_stored_attributes :enqueued_at, :started_at, :finished_at, :failed_at, :suspended_at, :resumed_at

  SUSPEND = 'suspend'.freeze

  def save!
    workflow.with_lock do
      workflow.set_job(self)
      workflow.save!
      yield if block_given?
    end
  end

  # execute this code by ActiveJob. You may return Burstflow::Job::SUSPEND to suspend job, or call suspend method
  def perform; end

  def perform_now
    run_callbacks :perform do
      perform
    end
  rescue StandardError => exception
    rescue_with_handler(exception) || raise
  end

  # execute this code when resumes after suspending
  def resume(data)
    raise InternalError.new(self, "Can't perform resume: not resumed") unless resumed?

    set_output(data)
  end

  def resume_now(data)
    run_callbacks :resume do
      resume(data)
    end
  rescue StandardError => exception
    rescue_with_handler(exception) || raise
  end

  # store data to be available for next jobs
  def set_output(data)
    self.output = data
  end

  # mark execution as suspended
  def suspend
    raise InternalError.new(self, "Can't suspend: not running") unless running?

    set_output(SUSPEND)
  end

  def configure(*args, &block)
    workflow.with_lock do
      builder = Burstflow::Workflow::Builder.new(workflow, *args, &block)
      workflow.flow['jobs_config'] = builder.as_json
      workflow.save!
      reload
    end
  end

  def attributes
    {
      workflow_id: workflow_id,
      id: id,
      klass: klass,
      params: params,
      incoming: incoming,
      outgoing: outgoing,
      output: output,
      started_at: started_at,
      enqueued_at: enqueued_at,
      finished_at: finished_at,
      failed_at: failed_at,
      suspended_at: suspended_at,
      resumed_at: resumed_at,
      failure: failure
    }
  end

end
