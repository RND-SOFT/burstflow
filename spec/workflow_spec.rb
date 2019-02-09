require 'spec_helper'

describe Burstflow::Workflow do
  WfJob1 = Class.new(Burstflow::Job)
  WfJob2 = Class.new(Burstflow::Job)
  WfJob3 = Class.new(Burstflow::Job)

  class Workflow1 < Burstflow::Workflow

    $conf1 = configure do |arg1, arg2|
      $jobid1 = run WfJob1, params: { param1: true, arg: arg1 }
      $jobid2 = run WfJob2, params: { param2: true, arg: arg2 }, after: WfJob1
      $jobid3 = run WfJob3, before: WfJob2, after: $jobid1
      $jobid4 = run WfJob3, after: $jobid3
    end

  end

  class Workflow2 < Burstflow::Workflow

    $conf2 = configure do |arg1, arg2|
      $jobid1 = run WfJob1, params: { param1: true, arg: arg1 }
      $jobid2 = run WfJob2, params: { param2: true, arg: arg2 }, after: WfJob1
      $jobid3 = run WfJob3, before: WfJob2, after: $jobid1
      $jobid4 = run WfJob3, after: $jobid3
    end

  end

  describe 'initializing' do
    it 'class level configuration' do
      expect(Burstflow::Workflow.configuration).to eq nil
      expect(Workflow1.configuration).to eq $conf1
      expect(Workflow2.configuration).to eq $conf2
      expect($conf1).not_to eq $conf2
    end

    it 'build' do
      Workflow1.build(:arg1, :arg2).save!
      wf1 = Workflow1.first
      jobs = wf1.flow['jobs_config']

      expect(jobs.count).to eq 4
      expect(wf1.initial_jobs.count).to eq 1

      expect(jobs[$jobid1]).to include(:id,
                                       klass: WfJob1.to_s,
                                       incoming: [],
                                       outgoing: [$jobid2, $jobid3],
                                       workflow_id: wf1.id,
                                       params: { 'param1' => true, 'arg' => 'arg1' })

      expect(jobs[$jobid2]).to include(:id,
                                       klass: WfJob2.to_s,
                                       incoming: [$jobid1, $jobid3],
                                       outgoing: [],
                                       workflow_id: wf1.id,
                                       params: { 'param2' => true, 'arg' => 'arg2' })

      expect(jobs[$jobid3]).to include(:id,
                                       klass: WfJob3.to_s,
                                       incoming: [$jobid1],
                                       outgoing: [$jobid2, $jobid4],
                                       workflow_id: wf1.id,
                                       params: nil)

      expect(jobs[$jobid4]).to include(:id,
                                       klass: WfJob3.to_s,
                                       incoming: [$jobid3],
                                       outgoing: [],
                                       workflow_id: wf1.id,
                                       params: nil)
    end
  end

  describe 'executing' do
    def perform_enqueued_job(wf, enqueued_job)
      enqueued_job[:job].new(*enqueued_job[:args]).perform_now

      queue_adapter.performed_jobs << enqueued_job
      queue_adapter.enqueued_jobs.delete(enqueued_job)

      wf.reload
    end

    def perform_enqueued_jobs_async
      jobs = Enumerator.new do |y|
        y << queue_adapter.enqueued_jobs.shift while queue_adapter.enqueued_jobs.count > 0
      end

      result = yield
      while queue_adapter.enqueued_jobs.count > 0

        threads = jobs.map do |job|
          Thread.new(job) do |job|
            job[:job].new(*job[:args]).perform_now
            queue_adapter.performed_jobs << job
          end
        end

        threads.each(&:join)
      end
      result
    end

    describe 'complex' do
      let(:wf){ Workflow1.build(:arg1, :arg2) }

      before do
        wf.start!
      end

      it 'success story one by one' do
        expect(Burstflow::Worker).to have_jobs(wf.id, [$jobid1])

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

      it 'success story all at once sync' do
        perform_enqueued_jobs do
          perform_enqueued_job(wf, queue_adapter.enqueued_jobs.first)
        end

        expect(queue_adapter.enqueued_jobs.count).to eq 0
        expect(wf.jobs.count(&:enqueued?)).to eq 4
        expect(wf.jobs.count(&:started?)).to eq 4
        expect(wf.jobs.count(&:finished?)).to eq 4
        expect(wf.jobs.count(&:ready_to_start?)).to eq 0
      end

      it 'success story all at once async', threads: true do
        perform_enqueued_jobs_async do
          perform_enqueued_job(wf, queue_adapter.enqueued_jobs.first)
        end

        wf.reload
        expect(queue_adapter.enqueued_jobs.count).to eq 0
        expect(wf.jobs.count(&:enqueued?)).to eq 4
        expect(wf.jobs.count(&:started?)).to eq 4
        expect(wf.jobs.count(&:finished?)).to eq 4
        expect(wf.jobs.count(&:ready_to_start?)).to eq 0
      end
    end

    describe 'concurrency' do
      class MapJob1 < Burstflow::Job

        def perform
          set_output(params['i'])
        end

      end

      class ReduceJob1 < Burstflow::Job

        def perform
          set_output(payloads.map{|p| p[:value] }.sum)
        end

      end

      class ConcWorkflow < Burstflow::Workflow

        configure do |size|
          size.to_i.times.to_a.shuffle.each do |i|
            run MapJob1, params: { i: i }, before: ReduceJob1
          end

          $jobid = run ReduceJob1
        end

      end

      let(:count){ 50 }
      let(:expected_result){ count.times.sum }

      it 'sync' do
        wf = perform_enqueued_jobs do
          ConcWorkflow.build(count).start!
        end.reload

        expect(wf.job($jobid).output).to eq expected_result
      end

      it 'threaded', threads: true do
        wf = perform_enqueued_jobs_async do
          ConcWorkflow.build(count).start!
        end.reload

        expect(wf.job($jobid).output).to eq expected_result
      end
    end

    describe 'simple' do
      WfSimpleJob = Class.new(Burstflow::Job)
      WfFailureJob = Class.new(Burstflow::Job) do
        def perform
          raise 'ex'
        end
      end

      WfSuspendJob = Class.new(Burstflow::Job) do
        def perform
          Burstflow::Job::SUSPEND
        end
      end

      describe 'parallel failure' do
        class Workflow3 < Burstflow::Workflow

          configure do |_arg1, _arg2|
            $jobid1 = run WfSimpleJob
            $jobid2 = run WfFailureJob
            $jobid3 = run WfSimpleJob, after: $jobid2
          end

        end

        it 'run' do
          wf = perform_enqueued_jobs do
            Workflow3.build.start!
          end.reload

          expect(wf.status).to eq Burstflow::Workflow::FAILED
          expect(wf.failures.first).to include(:created_at, job: $jobid2)

          expect(wf.job($jobid1).succeeded?).to eq true

          expect(wf.job($jobid2).succeeded?).to eq false
          expect(wf.job($jobid2).failed?).to eq true
          expect(wf.job($jobid2).failure).to include(klass: 'RuntimeError', message: 'ex')

          expect(wf.job($jobid3).enqueued?).to eq false
        end

        it "cancell" do
          wf = Workflow3.build.start!
          perform_enqueued_jobs_async do
            wf.cancelled!
          end

          expect(wf.status).to eq Burstflow::Workflow::CANCELLED
        end
      end

      describe 'parallel suspend' do
        class Workflow4 < Burstflow::Workflow

          configure do |_arg1, _arg2|
            $jobid1 = run WfSimpleJob
            $jobid2 = run WfSuspendJob
            $jobid3 = run WfSimpleJob, after: $jobid2
          end

        end

        it 'run' do
          wf = perform_enqueued_jobs do
            Workflow4.build.start!
          end.reload

          expect(wf.status).to eq Burstflow::Workflow::SUSPENDED

          expect(wf.job($jobid1).succeeded?).to eq true
          expect(wf.job($jobid2).suspended?).to eq true
          expect(wf.job($jobid3).enqueued?).to eq false

          wf = perform_enqueued_jobs do
            wf.resume!($jobid2, 'gogogo')
          end.reload

          expect(wf.status).to eq Burstflow::Workflow::SUCCEEDED

          expect(wf.job($jobid1).succeeded?).to eq true
          expect(wf.job($jobid2).succeeded?).to eq true
          expect(wf.job($jobid3).succeeded?).to eq true
        end
      end

      describe 'dynamic job creation' do
        let(:count) { 10 }
        let(:expected_result) { (count + 1).times.sum }

        WfDynamicJob = Class.new(Burstflow::Job) do
          def perform
            if params['i'] > 0
              configure(id, params) do |id, params|
                $lasjobid = run WfDynamicJob, params: { i: params['i'] - 1 }, after: id
              end
            end

            output = if payload = payloads.first
                       payload[:value] + params['i']
                     else
                       params['i']
            end

            set_output(output)
          end
        end

        class WorkflowDynamic < Burstflow::Workflow

          configure do |count|
            run WfDynamicJob, params: { i: count }
          end

        end

        it 'run' do
          wf = WorkflowDynamic.build(count)
          wf.save!

          expect(wf.jobs.count).to eq 1

          wf = perform_enqueued_jobs do
            WorkflowDynamic.build(count).start!
          end.reload

          expect(wf.jobs.count).to eq 11
          expect(wf.job($lasjobid).output).to eq expected_result
        end
      end

      describe 'callbacks' do
        WfCallJob = Class.new(Burstflow::Job) do
          before_enqueue :be
          before_perform :bp
          before_suspend :bs
          before_resume  :br
          before_failure :bf

          def be
            $be = true
          end

          def bp
            $bp = true
          end

          def bs
            $bs = true
          end

          def br
            $br = true
          end

          def bf
            $bf = true
          end

          def perform
            suspend
          end

          def resume(_data)
            raise 'ex'
          end
        end

        class WorkflowCall < Burstflow::Workflow

          before_suspend :wbs
          before_resume  :wbr
          before_failed  :wbf
          before_finished  :wbfs

          def wbs
            $wbs = true
          end

          def wbr
            $wbr = true
          end

          def wbf
            $wbf = true
          end

          def wbfs
            $wbfs = true
          end

          configure do
            $jobid1 = run WfCallJob
          end

        end

        it 'run' do
          expect([$be, $bp, $bs, $br, $bf].any?).to eq false
          expect([$wbs, $wbr, $wbf, $wbfs].any?).to eq false

          wf = perform_enqueued_jobs do
            WorkflowCall.build.start!
          end.reload

          wf = perform_enqueued_jobs do
            wf.resume!($jobid1, '123123123')
          end.reload

          expect(wf.status).to eq Burstflow::Workflow::FAILED
          expect(wf.failures.first).to include(:created_at, job: $jobid1)

          expect(wf.job($jobid1).succeeded?).to eq false
          expect(wf.job($jobid1).failed?).to eq true
          expect(wf.job($jobid1).failure).to include(klass: 'RuntimeError', message: 'ex')

          expect([$be, $bp, $bs, $br, $bf].all?).to eq true
          expect([$wbs, $wbr, $wbf, $wbfs].all?).to eq true
        end
      end
    end
  end

  context 'model' do
    let(:w){Burstflow::Workflow.new}

    it 'default store' do
      expect(w.attributes).to include(:id, jobs_config: {}, type: Burstflow::Workflow.to_s)

      expect(w.initial?).to eq true
      expect(w.failed?).to eq false
      expect(w.finished?).to eq false
      expect(w.running?).to eq false
      expect(w.suspended?).to eq false
      expect(w.status).to eq Burstflow::Workflow::INITIAL
    end

    it 'store persistance' do
      w.save!

      w2 = Burstflow::Workflow.find(w.id)
      expect(w2.attributes).to include(w.attributes)
    end

    let(:wfc) {
      Class.new(Burstflow::Workflow) do
        options uniq: true
      end
    }

    it "singleton" do
      expect(w.singleton?).to be_falsey
      expect(wfc.new.singleton?).to eq true
    end

    describe "states" do
      it "failed" do
        w.running!
        w.failed!

        expect(w.failed?).to eq true
        expect(w.succeeded?).to eq false
        expect(w.finished?).to eq true
      end

      it "succeeded" do
        w.running!
        w.succeeded!

        expect(w.failed?).to eq false
        expect(w.succeeded?).to eq true
        expect(w.finished?).to eq true
      end

      it "calcelled" do
        w.running!
        w.cancelled!

        expect(w.failed?).to eq false
        expect(w.succeeded?).to eq false
        expect(w.cancelled?).to eq true
        expect(w.finished?).to eq true
      end
    end
  end
end
