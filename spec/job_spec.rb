require 'spec_helper'

describe Burstflow::Job do
  let(:w) { Burstflow::Workflow.new }

  context 'initializing' do
    class TestJob1 < Burstflow::Job
    end

    subject{ TestJob1.new(w, {}.with_indifferent_access) }

    it 'empty' do
      expect(subject.workflow_id).to eq w.id
      expect(subject.klass).to eq TestJob1.to_s

      expect(subject.incoming).to eq []
      expect(subject.outgoing).to eq []

      expect(subject.initial?).to eq true

      expect(subject.enqueued?).to eq false
      expect(subject.started?).to eq false
      expect(subject.finished?).to eq false
      expect(subject.failed?).to eq false
      expect(subject.suspended?).to eq false
      expect(subject.resumed?).to eq false

      expect(subject.ready_to_start?).to eq true
    end

    it '#enqueue!' do
      subject.enqueue!

      expect(subject.enqueued?).to eq true
      expect(subject.ready_to_start?).to eq false
    end

    it '#start!' do
      subject.start!

      expect(subject.started?).to eq true
      expect(subject.ready_to_start?).to eq false
    end

    it '#finish!' do
      subject.finish!

      expect(subject.finished?).to eq true
      expect(subject.succeeded?).to eq true
      expect(subject.failed?).to eq false
      expect(subject.ready_to_start?).to eq false
    end

    it '#fail!' do
      subject.fail!

      expect(subject.finished?).to eq true
      expect(subject.succeeded?).to eq false
      expect(subject.failed?).to eq true
      expect(subject.ready_to_start?).to eq false
    end

    it '#suspend!' do
      subject.suspend!

      expect(subject.finished?).to eq false
      expect(subject.suspended?).to eq true
      expect(subject.ready_to_start?).to eq true
    end

    it '#resume!' do
      subject.suspend!
      subject.resume!

      expect(subject.finished?).to eq false
      expect(subject.resumed?).to eq true
      expect(subject.ready_to_start?).to eq true
    end
  end
end
