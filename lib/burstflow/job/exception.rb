class Burstflow::Job::InternalError < ::RuntimeError

  attr_accessor :job

  def initialize(job, message)
    @job = job
    super(message)
  end

end
