class Burstflow::Workflow::InternalError < ::RuntimeError

  attr_accessor :workflow

  def initialize(workflow, message)
    @workflow = workflow
    super(message)
  end

end
