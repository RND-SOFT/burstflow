require 'spec_helper'

describe Burst::Job do
  include ActiveJob::TestHelper
  
  let(:w) {Burst::Workflow.new()}

  context "initializing" do 

    class TestJob1 < Burst::Job
    end

    it "empty" do
      hash = {}.with_indifferent_access
      job = TestJob1.new(w, hash)

      expect(job.workflow_id).to eq w.id
      expect(job.klass).to eq TestJob1.to_s
      expect(job.finished?).to eq false
      expect(job.started?).to eq false
      expect(job.initial?).to eq true

      expect(job.ready_to_start?).to eq true
    end
  end
  

end
