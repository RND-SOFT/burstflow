require 'spec_helper'

describe Burstflow::Workflow do
  Job1 = Class.new(Burstflow::Job)
  Job2 = Class.new(Burstflow::Job)
  Job3 = Class.new(Burstflow::Job)

  Workflow1 = Class.new(Burstflow::Workflow) do
    $conf1 = configure do |arg1, arg2|
      $jobid1 = run Job1, params: { param1: true, arg: arg1}
      $jobid2 = run Job2, params: { param2: true, arg: arg2}, after: Job1
      $jobid3 = run Job3, before: Job2, after: $jobid1
      $jobid4 = run Job3, after: $jobid3
    end
  end

  Workflow2 = Class.new(Burstflow::Workflow) do
    $conf2 = configure do |arg1, arg2|
      $jobid1 = run Job1, params: { param1: true, arg: arg1}
      $jobid2 = run Job2, params: { param2: true, arg: arg2}, after: Job1
      $jobid3 = run Job3, before: Job2, after: $jobid1
      $jobid4 = run Job3, after: $jobid3
    end
  end

  describe "initializing" do
    it "class level configuration" do
      expect(Burstflow::Workflow.configuration).to eq nil
      expect(Workflow1.configuration).to eq $conf1
      expect(Workflow2.configuration).to eq $conf2
      expect($conf1).not_to eq $conf2
    end

    it "build" do
      Workflow1.build(:arg1, :arg2).save!
      wf1 = Workflow1.first
      jobs = wf1.flow['jobs_config']

      expect(jobs.count).to eq 4
      expect(wf1.initial_jobs.count).to eq 1

      expect(jobs[$jobid1]).to include(:id, 
        klass: Job1.to_s,
        incoming: [],
        outgoing: [$jobid2, $jobid3],
        workflow_id: wf1.id,
        params: {'param1' => true, 'arg' => 'arg1'})

      expect(jobs[$jobid2]).to include(:id,
        klass: Job2.to_s,
        incoming: [$jobid1, $jobid3],
        outgoing: [],
        workflow_id: wf1.id,
        params: {'param2' => true, 'arg' => 'arg2'})

      expect(jobs[$jobid3]).to include(:id,
        klass: Job3.to_s,
        incoming: [$jobid1],
        outgoing: [$jobid2, $jobid4],
        workflow_id: wf1.id,
        params: nil)

      expect(jobs[$jobid4]).to include(:id,
        klass: Job3.to_s,
        incoming: [$jobid3],
        outgoing: [],
        workflow_id: wf1.id,
        params: nil)
    end

  end

  describe "executing" do

    def perform_enqueued_job wf, enqueued_job
      enqueued_job[:job].new.perform(*enqueued_job[:args])
      queue_adapter.enqueued_jobs.delete(enqueued_job)
      wf.reload
    end

    def perform_enqueued_jobs_async
      while queue_adapter.enqueued_jobs.count > 0 do
        threads = queue_adapter.enqueued_jobs.map do |job|
          Thread.new(queue_adapter.enqueued_jobs.delete(job)) do |job|
            job[:job].new.perform(*job[:args])
          end
        end

        threads.each(&:join)
      end
    end

    describe "complex" do
      let(:wf){Workflow1.build(:arg1, :arg2)}

      before do
        wf.start!
      end

      it "success story one by one" do
        expect(queue_adapter.enqueued_jobs.count).to eq 1
        expect(queue_adapter.enqueued_jobs.first).to include(args: [wf.id, $jobid1])
        expect(wf.jobs.count(&:enqueued?)).to eq 1
        expect(wf.jobs.count(&:started?)).to eq 0
        expect(wf.jobs.count(&:finished?)).to eq 0
        expect(wf.jobs.count(&:ready_to_start?)).to eq 0

        perform_enqueued_job(wf, queue_adapter.enqueued_jobs.first)
        expect(queue_adapter.enqueued_jobs.count).to eq 1
        expect(queue_adapter.enqueued_jobs.first).to include(args: [wf.id, $jobid3])
        expect(wf.jobs.count(&:enqueued?)).to eq 2
        expect(wf.jobs.count(&:started?)).to eq 1
        expect(wf.jobs.count(&:finished?)).to eq 1
        expect(wf.jobs.count(&:ready_to_start?)).to eq 0
    
        perform_enqueued_job(wf, queue_adapter.enqueued_jobs.first)
        expect(queue_adapter.enqueued_jobs.count).to eq 2
        expect(queue_adapter.enqueued_jobs.first).to include(args: [wf.id, $jobid2])
        expect(queue_adapter.enqueued_jobs.last).to include(args: [wf.id, $jobid4])
        expect(wf.jobs.count(&:enqueued?)).to eq 4
        expect(wf.jobs.count(&:started?)).to eq 2
        expect(wf.jobs.count(&:finished?)).to eq 2
        expect(wf.jobs.count(&:ready_to_start?)).to eq 0

        perform_enqueued_job(wf, queue_adapter.enqueued_jobs.first)
        expect(queue_adapter.enqueued_jobs.last).to include(args: [wf.id, $jobid4])
        expect(queue_adapter.enqueued_jobs.count).to eq 1
        expect(wf.jobs.count(&:enqueued?)).to eq 4
        expect(wf.jobs.count(&:started?)).to eq 3
        expect(wf.jobs.count(&:finished?)).to eq 3
        expect(wf.jobs.count(&:ready_to_start?)).to eq 0
        
        perform_enqueued_job(wf, queue_adapter.enqueued_jobs.first)
        expect(queue_adapter.enqueued_jobs.count).to eq 0
        expect(wf.jobs.count(&:enqueued?)).to eq 4
        expect(wf.jobs.count(&:started?)).to eq 4
        expect(wf.jobs.count(&:finished?)).to eq 4
        expect(wf.jobs.count(&:ready_to_start?)).to eq 0

      end

      it "success story all at once sync" do
        perform_enqueued_jobs do
          perform_enqueued_job(wf, queue_adapter.enqueued_jobs.first)
        end

        expect(queue_adapter.enqueued_jobs.count).to eq 0
        expect(wf.jobs.count(&:enqueued?)).to eq 4
        expect(wf.jobs.count(&:started?)).to eq 4
        expect(wf.jobs.count(&:finished?)).to eq 4
        expect(wf.jobs.count(&:ready_to_start?)).to eq 0
      end

      describe "threads", threads: true do 
        it "success story all at once async" do
          perform_enqueued_jobs_async

          wf.reload
          expect(queue_adapter.enqueued_jobs.count).to eq 0
          expect(wf.jobs.count(&:enqueued?)).to eq 4
          expect(wf.jobs.count(&:started?)).to eq 4
          expect(wf.jobs.count(&:finished?)).to eq 4
          expect(wf.jobs.count(&:ready_to_start?)).to eq 0
        end
      end
    end

    describe "simple" do
      SimpleJob = Class.new(Burstflow::Job)
      FailureJob = Class.new(Burstflow::Job) do
        def perform 
          raise "ex"
        end
      end

      SuspendJob = Class.new(Burstflow::Job) do
        def perform 
          return Burstflow::Job::SUSPEND
        end
      end

      describe "parallel failure" do
        Workflow = Class.new(Burstflow::Workflow) do
          configure do |arg1, arg2|
            $jobid1 = run SimpleJob
            $jobid2 = run FailureJob
            $jobid3 = run SimpleJob, after: $jobid2
          end
        end

        it "run" do
          wf = perform_enqueued_jobs do
            Workflow.build.start!
          end.reload

          expect(wf.status).to eq Burstflow::Workflow::FAILED
          expect(wf.failures.first).to include(job: $jobid2, msg: 'ex')

          expect(wf.job($jobid1).succeeded?).to eq true

          expect(wf.job($jobid2).succeeded?).to eq false
          expect(wf.job($jobid2).failed?).to eq true

          expect(wf.job($jobid3).enqueued?).to eq false
        end
      end

      describe "parallel suspend" do
        Workflow = Class.new(Burstflow::Workflow) do
          configure do |arg1, arg2|
            $jobid1 = run SimpleJob
            $jobid2 = run SuspendJob
            $jobid3 = run SimpleJob, after: $jobid2
          end
        end

        it "run" do
          wf = perform_enqueued_jobs do
            Workflow.build.start!
          end.reload

          expect(wf.status).to eq Burstflow::Workflow::SUSPENDED

          expect(wf.job($jobid1).succeeded?).to eq true
          expect(wf.job($jobid2).suspended?).to eq true
          expect(wf.job($jobid3).enqueued?).to eq false

          wf = perform_enqueued_jobs do
            wf.resume!($jobid2, "gogogo")
          end.reload

          expect(wf.status).to eq Burstflow::Workflow::FINISHED

          expect(wf.job($jobid1).succeeded?).to eq true
          expect(wf.job($jobid2).succeeded?).to eq true
          expect(wf.job($jobid3).succeeded?).to eq true
        end
      end


    end

  end

  class TestJob < Burstflow::Job

    def perform
      # puts "#{self.class} perform"
    end

  end

  class WfJob1 < TestJob
  end

  class WfJob2 < TestJob
  end

  class WfJob3 < TestJob
  end


  class W1 < Burstflow::Workflow

    configure do |*_args|
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
    expect(j3.outgoing).to include

    expect(j1.incoming).to include
    expect(j2.incoming).to include(j1.id)
    expect(j3.incoming).to include(j1.id, j2.id)

    expect(j1.initial?).to eq true
    expect(j2.initial?).to eq false
    expect(j3.initial?).to eq false
  end

  context 'model' do
    it 'default store' do
      w = Burstflow::Workflow.new

      expect(w.attributes).to include(:id, jobs: {}, klass: Burstflow::Workflow.to_s)

      expect(w.started?).to eq false
      expect(w.failed?).to eq false
      expect(w.finished?).to eq true
      expect(w.running?).to eq false
      expect(w.status).to eq Burstflow::Workflow::FINISHED
    end

    it 'store persistance' do
      w = Burstflow::Workflow.new
      w.save!

      w2 = Burstflow::Workflow.find(w.id)
      expect(w2.attributes).to include(w.attributes)
    end

    it 'builded store' do
      w = W1.build

      jobs = w.jobs
      expect_jobs(*jobs.values.map{|json| Burstflow::Job.new(w, json) })

      expect(w.attributes).to include(:id, jobs: jobs, klass: W1.to_s)
    end

    it 'builded persistance' do
      w = W1.build
      w.save!

      jobs = w.jobs
      expect_jobs(*jobs.values.map{|json| Burstflow::Job.new(w, json) })

      w2 = Burstflow::Workflow.find(w.id)
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
    expect(j3.outgoing).to include

    expect(j1.incoming).to include
    expect(j2.incoming).to include(j1.id)
    expect(j3.incoming).to include(j1.id, j2.id)

    expect(j1.initial?).to eq true
    expect(j2.initial?).to eq false
    expect(j3.initial?).to eq false

    expect(w.initial_jobs).to include(j1)
  end

  it 'check builder' do
    w = W1.build
    expect_wf(w)

    expect(w.status)
  end

  it 'check persistance' do
    w = W1.build
    w.save!

    w2 = W1.find(w.id)
    expect_wf(w2)
  end

  it 'start without perform' do
    w = W1.build
    w.save!

    expect(w.started?).to eq false
    expect(w.failed?).to eq false
    expect(w.finished?).to eq false
    expect(w.running?).to eq false
    expect(w.status).to eq Burstflow::Workflow::INITIAL

    w.start!

    expect(Burstflow::Worker).to have_jobs(w.id, ['job1'])
    expect(Burstflow::Worker).not_to have_jobs(w.id, ['job2'])

    w = W1.find(w.id)

    expect(w.started?).to eq false
    expect(w.failed?).to eq false
    expect(w.finished?).to eq false
    expect(w.running?).to eq false
    expect(w.status).to eq Burstflow::Workflow::INITIAL
  end

  it 'start with perform' do
    w = W1.build
    w.save!

    expect(w.started?).to eq false
    expect(w.failed?).to eq false
    expect(w.finished?).to eq false
    expect(w.running?).to eq false
    expect(w.status).to eq Burstflow::Workflow::INITIAL

    perform_enqueued_jobs do
      w.start!
    end

    w = W1.find(w.id)

    expect(w.started?).to eq true
    expect(w.failed?).to eq false
    expect(w.finished?).to eq true
    expect(w.running?).to eq false
    expect(w.status).to eq Burstflow::Workflow::FINISHED
  end
end
