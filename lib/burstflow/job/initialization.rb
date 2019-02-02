module Burstflow::Job::Initialization
  extend  ActiveSupport::Concern

  included do

    def initialize(workflow, job_config = {})
      @workflow = workflow
      assign_default_values(job_config)
    end

    def assign_default_values(job_config)
      set_model(job_config.deep_dup)

      self.id ||= SecureRandom.uuid
      self.workflow_id ||= @workflow.try(:id)
      self.klass ||= self.class.to_s
      self.incoming ||= []
      self.outgoing ||= []
    end

    def reload
      assign_default_values(@workflow.job_hash(self.id))
    end

  end

  class_methods do

    def from_hash(workflow, job_config)
      job_config[:klass].constantize.new(workflow, job_config)
    end

  end

end