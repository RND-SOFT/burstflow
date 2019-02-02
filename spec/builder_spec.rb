require 'spec_helper'
require 'pp'

describe Burstflow::Workflow::Builder do
  context 'initializing' do
    Job1 = Class.new(Burstflow::Job)
    Job2 = Class.new(Burstflow::Job)
    Job3 = Class.new(Burstflow::Job)

    let(:workflow){double(:workflow, id: 'id1')}

    it 'without dependencies' do
      builder = Burstflow::Workflow::Builder.new workflow do 
        $jobid1 = run Job1, params: { param1: true }
      end

      flow = builder.as_json
      expect(flow.count).to eq 1

      expect(flow[$jobid1]).to include(:id, :incoming, :outgoing, workflow_id: 'id1', params: {'param1' => true})
    end

    it 'with dependencies' do
      builder = Burstflow::Workflow::Builder.new workflow, :arg1, :arg2 do |arg1, arg2|
        $jobid1 = run Job1, params: { param1: true, arg: arg1}
        $jobid2 = run Job2, params: { param2: true, arg: arg2}, after: Job1
        $jobid3 = run Job3, before: Job2, after: $jobid1
        $jobid4 = run Job3, after: $jobid3
      end

      flow = builder.as_json
      expect(flow.count).to eq 4

      expect(flow[$jobid1]).to include(:id, 
        klass: Job1.to_s,
        incoming: [],
        outgoing: [$jobid2, $jobid3],
        workflow_id: 'id1',
        params: {'param1' => true, 'arg' => :arg1})

      expect(flow[$jobid2]).to include(:id,
        klass: Job2.to_s,
        incoming: [$jobid1, $jobid3],
        outgoing: [],
        workflow_id: 'id1',
        params: {'param2' => true, 'arg' => :arg2})

      expect(flow[$jobid3]).to include(:id,
        klass: Job3.to_s,
        incoming: [$jobid1],
        outgoing: [$jobid2, $jobid4],
        workflow_id: 'id1',
        params: nil)

      expect(flow[$jobid4]).to include(:id,
        klass: Job3.to_s,
        incoming: [$jobid3],
        outgoing: [],
        workflow_id: 'id1',
        params: nil)
    end

  end
end
