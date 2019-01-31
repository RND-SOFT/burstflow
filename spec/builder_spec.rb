require 'spec_helper'
require 'pp'

describe Burstflow::Helpers::Builder do
  context 'initializing' do
    JobClass1 = Class.new(Burstflow::Job)
    JobClass2 = Class.new(Burstflow::Job)
    JobClass3 = Class.new(Burstflow::Job)

    it 'without dependencies' do
      builder = Burstflow::Helpers::Builder.new "id1" do 
        $jobid1 = run JobClass1, params: { param1: true }
      end

      flow = builder.as_json
      expect(flow.count).to eq 1

      expect(flow[$jobid1]).to include(:id, :incoming, :outgoing, workflow_id: 'id1', params: {'param1' => true})
    end

    it 'with dependencies' do
      builder = Burstflow::Helpers::Builder.new "id1", :arg1, :arg2 do |arg1, arg2|
        $jobid1 = run JobClass1, params: { param1: true, arg: arg1}
        $jobid2 = run JobClass2, params: { param2: true, arg: arg2}, after: JobClass1
        $jobid3 = run JobClass3, before: JobClass2, after: $jobid1
        $jobid4 = run JobClass3, after: $jobid3
      end

      flow = builder.as_json
      expect(flow.count).to eq 4

      expect(flow[$jobid1]).to include(:id, 
        klass: JobClass1.to_s,
        incoming: [],
        outgoing: [$jobid2, $jobid3],
        workflow_id: 'id1',
        params: {'param1' => true, 'arg' => :arg1})

      expect(flow[$jobid2]).to include(:id,
        klass: JobClass2.to_s,
        incoming: [$jobid1, $jobid3],
        outgoing: [],
        workflow_id: 'id1',
        params: {'param2' => true, 'arg' => :arg2})

      expect(flow[$jobid3]).to include(:id,
        klass: JobClass3.to_s,
        incoming: [$jobid1],
        outgoing: [$jobid2, $jobid4],
        workflow_id: 'id1',
        params: nil)

      expect(flow[$jobid4]).to include(:id,
        klass: JobClass3.to_s,
        incoming: [$jobid3],
        outgoing: [],
        workflow_id: 'id1',
        params: nil)
    end

  end
end
