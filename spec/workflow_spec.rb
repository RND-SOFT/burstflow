require 'spec_helper'

describe Burst::Workflow do
  include ActiveJob::TestHelper
  

  class TestJob < Burst::Job
    def perform
      #puts "#{self.class} perform"
    end
  end

  class WfJob1 < TestJob
  end

  class WfJob2 < TestJob
  end

  class WfJob3 < TestJob
  end
 

  class W1 < Burst::Workflow
    def configure
      id1 = run WfJob1, id: 'job1'
      run WfJob2, id: 'job2', after: id1
      run WfJob3, after: [WfJob1, 'job2']
    end
  end

  def expect_jobs(*jobs)
    j1, j2, j3 = *jobs

    expect(j1.finished?).to eq false
    expect(j2.finished?).to eq false

    expect(j1.klass).to eq 'WfJob1'
    expect(j2.klass).to eq 'WfJob2'
    expect(j3.klass).to eq 'WfJob3'

    expect(j1.outgoing).to include(j2.id, j3.id)
    expect(j2.outgoing).to include(j3.id)
    expect(j3.outgoing).to include()

    expect(j1.incoming).to include()
    expect(j2.incoming).to include(j1.id)
    expect(j3.incoming).to include(j1.id, j2.id)

    expect(j1.initial?).to eq true
    expect(j2.initial?).to eq false
    expect(j3.initial?).to eq false
  end

  context "model" do
    it "default store" do
      w = Burst::Workflow.new()

      expect(w.attributes).to include(:id, jobs: {}, klass: Burst::Workflow.to_s)

      expect(w.started?).to eq false
      expect(w.failed?).to eq false
      expect(w.finished?).to eq true
      expect(w.running?).to eq false
      expect(w.status).to eq Burst::Workflow::FINISHED
    end

    it "store persistance" do
      w = Burst::Workflow.new()
      w.save!

      w2 = Burst::Workflow.find(w.id)
      expect(w2.attributes).to include(w.attributes)
    end

    it "builded store" do
      w = W1.build

      jobs = w.jobs
      expect_jobs(*jobs.values.map{|json| Burst::Job.new(w, json)})

      expect(w.attributes).to include(:id, jobs: jobs, klass: W1.to_s)
    end

    it "builded persistance" do
      w = W1.build
      w.save!

      jobs = w.jobs
      expect_jobs(*jobs.values.map{|json| Burst::Job.new(w, json)})

      w2 = Burst::Workflow.find(w.id)
      expect(w2.attributes).to include(w.attributes)
    end
  end

  def expect_wf(w)
    j1 = w.find_job('job1')
    j2 = w.find_job('job2')
    j3 = w.find_job(WfJob3)

    expect(j1.finished?).to eq false
    expect(j2.finished?).to eq false

    expect(j1.klass).to eq 'WfJob1'
    expect(j2.klass).to eq 'WfJob2'
    expect(j3.klass).to eq 'WfJob3'

    expect(j1.outgoing).to include(j2.id, j3.id)
    expect(j2.outgoing).to include(j3.id)
    expect(j3.outgoing).to include()

    expect(j1.incoming).to include()
    expect(j2.incoming).to include(j1.id)
    expect(j3.incoming).to include(j1.id, j2.id)

    expect(j1.initial?).to eq true
    expect(j2.initial?).to eq false
    expect(j3.initial?).to eq false

    expect(w.initial_jobs).to include(j1)
  end

  it "check builder" do
    w = W1.build
    expect_wf(w)

    expect(w.status)
  end

  it "check persistance" do
    w = W1.build
    w.save!

    w2 = W1.find(w.id)
    expect_wf(w2)
  end
  
  it "start without perform" do
    w = W1.build
    w.save!

    expect(w.started?).to eq false
    expect(w.failed?).to eq false
    expect(w.finished?).to eq false
    expect(w.running?).to eq false
    expect(w.status).to eq Burst::Workflow::INITIAL

    w.start!

    w = W1.find(w.id)

    expect(w.started?).to eq false
    expect(w.failed?).to eq false
    expect(w.finished?).to eq false
    expect(w.running?).to eq false
    expect(w.status).to eq Burst::Workflow::INITIAL
  end

  it "start with perform" do
    w = W1.build
    w.save!

    expect(w.started?).to eq false
    expect(w.failed?).to eq false
    expect(w.finished?).to eq false
    expect(w.running?).to eq false
    expect(w.status).to eq Burst::Workflow::INITIAL

    perform_enqueued_jobs do
      w.start!
    end

    w = W1.find(w.id)

    expect(w.started?).to eq true
    expect(w.failed?).to eq false
    expect(w.finished?).to eq true
    expect(w.running?).to eq false
    expect(w.status).to eq Burst::Workflow::FINISHED
  end

end
