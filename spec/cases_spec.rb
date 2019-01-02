require 'spec_helper'

describe Burst::Manager do
  include ActiveJob::TestHelper
  
  class JobHandler
    attr_accessor :jobs

    def initialize; @jobs = []; end
    def add json; @jobs.push json; end

    def find_job klass
      @jobs.detect do |json|
        json['klass'].to_s == klass.to_s
      end
    end
  end

  around :each do |ex|
    begin
      $job_handler = JobHandler.new()
      ex.run
    ensure
      $job_handler = nil
    end
  end

  class TestCaseJob < Burst::Job
    def perform 
      #puts "#{self.class.to_s}"
      set_output(self.class.to_s)
      $job_handler.add self.as_json.with_indifferent_access.merge(payloads: self.payloads)
    end
  end

  class CaseJob1 < TestCaseJob; end
  class CaseJob2 < TestCaseJob; end
  class CaseJob3 < TestCaseJob; end
  class CaseAsyncJob < TestCaseJob
    def perform
      suspend
      $job_handler.add self.as_json.with_indifferent_access.merge(payloads: self.payloads)
    end
  end

 

  class CaseW1 < Burst::Workflow
    def configure
      id1 = run CaseJob1, id: 'job1', params: {p1: 1}
      run CaseJob2, id: 'job2', after: id1, params: {p2: 2}
      run CaseJob3, after: [CaseJob1, 'job2']
    end
  end


  it "case1 no async job state" do
    w = CaseW1.build

    perform_enqueued_jobs do
      w.start!
    end

    w.reload

    expect(w.started?).to eq true
    expect(w.failed?).to eq false
    expect(w.finished?).to eq true
    expect(w.running?).to eq false
    expect(w.status).to eq Burst::Workflow::FINISHED

    expect($job_handler.jobs.count).to eq 3
    expect($job_handler.find_job(CaseJob1)).to include(output: 'CaseJob1', params: {p1: 1})

    expect($job_handler.find_job(CaseJob2)).to include(output: 'CaseJob2', params: {p2: 2})
    expect($job_handler.find_job(CaseJob2)[:payloads]).to include({id: 'job1', class: 'CaseJob1', payload: 'CaseJob1'})

    expect($job_handler.find_job(CaseJob3)).to include(output: 'CaseJob3')
    expect($job_handler.find_job(CaseJob3)[:payloads]).to include({id: 'job1', class: 'CaseJob1', payload: 'CaseJob1'})
    expect($job_handler.find_job(CaseJob3)[:payloads]).to include({id: 'job2', class: 'CaseJob2', payload: 'CaseJob2'})
  end

  class CaseW2 < Burst::Workflow
    def configure
      id1 = run CaseJob1, id: 'job1', params: {p1: 1}
      run CaseAsyncJob, id: 'job2', after: id1, params: {p2: 2}
      run CaseJob3, after: [CaseJob1, 'job2']
    end
  end

  it "case2 with async job state" do
    w = CaseW2.build

    perform_enqueued_jobs do
      w.start!
    end

    w.reload

    expect(w.started?).to eq true
    expect(w.failed?).to eq false
    expect(w.finished?).to eq false
    expect(w.running?).to eq true
    expect(w.suspended?).to eq true
    expect(w.status).to eq Burst::Workflow::SUSPENDED

    expect($job_handler.jobs.count).to eq 2
    expect($job_handler.find_job(CaseJob1)).to include(output: 'CaseJob1', params: {p1: 1})

    expect($job_handler.find_job(CaseAsyncJob)).to include(output: Burst::Job::SUSPEND, params: {p2: 2})
    expect($job_handler.find_job(CaseAsyncJob)[:payloads]).to include({id: 'job1', class: 'CaseJob1', payload: 'CaseJob1'})

    w = CaseW2.find(w.id)

    perform_enqueued_jobs do
      w.continue!('job2', 'result')
    end

    w.reload

    expect($job_handler.jobs.count).to eq 3
    expect($job_handler.find_job(CaseJob1)).to include(output: 'CaseJob1', params: {p1: 1})

    #expect($job_handler.find_job(AsyncJob)).to include(output: 'result', params: {p2: 2})
    expect($job_handler.find_job(CaseAsyncJob)[:payloads]).to include({id: 'job1', class: 'CaseJob1', payload: 'CaseJob1'})

    expect($job_handler.find_job(CaseJob3)).to include(output: 'CaseJob3')
    expect($job_handler.find_job(CaseJob3)[:payloads]).to include({id: 'job1', class: 'CaseJob1', payload: 'CaseJob1'})
    expect($job_handler.find_job(CaseJob3)[:payloads]).to include({id: 'job2', class: 'CaseAsyncJob', payload: 'result'})
  end


end
