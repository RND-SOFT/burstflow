module Burstflow

  class Manager

    attr_accessor :workflow

    def initialize(workflow)
      @workflow = workflow
    end

    # workflow management

    def start_workflow!
      workflow.with_lock do
        return false unless workflow.allow_to_start?

        workflow.run_callbacks :run do
          workflow.running!
          
          workflow.initial_jobs.each do |job|
            enqueue_job!(job)
          end
        end
      end
    end

    def resume_workflow!(job_id, data)
      workflow.with_lock do
        workflow.run_callbacks :resume do
          workflow.resumed!

          job = workflow.job(job_id)
          resume_job!(job, data)
        end
      end
    end

    # Mark job enqueued and enqueue it
    def enqueue_job!(job)
      job.run_callbacks :enqueue do
        job.enqueue!
        job.save! do
          Burstflow::Worker.perform_later(workflow.id, job.id)
        end
      end
    end

    # Enqueue job for resuming
    def resume_job!(job, data)
      job.save! do
        Burstflow::Worker.perform_later(workflow.id, job.id, data)
      end
    end

    # Mark job suspended and forget it until resume
    def suspend_job!(job)
      job.run_callbacks :suspend do
        job.suspend!
        job.save! do
          analyze_workflow_state(job)
        end
      end
    end

    # Mark job finished and make further actions
    def finish_job!(job)
      job.finish!
      job.save! do
        analyze_workflow_state(job)
      end
    end

    # Mark job failed and make further actions
    def fail_job!(job, exception)
      job.run_callbacks :failure do
        job.fail! exception
        workflow.add_error(job)
        workflow.save!

        job.save! do
          analyze_workflow_state(job)
        end
      end
    end

    # Mark job finished or suspended depends on result or output
    def job_performed!(job, result)
      if result == Burstflow::Job::SUSPEND || job.output == Burstflow::Job::SUSPEND
        suspend_job!(job)
      else
        finish_job!(job)
      end
    rescue StandardError => e
      raise Burstflow::Workflow::InternalError.new(workflow, e.message)
    end

    private

      # analyze job completition, current workflow state and perform futher actions
      def analyze_workflow_state(job)
        unless ActiveRecord::Base.connection.open_transactions > 0
          raise Burstflow::Workflow::InternalError.new(workflow, 'analyze_workflow_state must be called in transaction with lock!')
        end

        if workflow.cancelled?
          # do nothing
          # workflow cancelled
        elsif job.succeeded? && job.outgoing.any? && !workflow.has_errors?
          return enqueue_outgoing_jobs(job)
        else
          if workflow.has_scheduled_jobs?
            # do nothing
            # scheduled jobs will perform finish action
          else
            workflow.complete!
          end
        end
      end

      # enqueue outgoing jobs if all requirements are met
      def enqueue_outgoing_jobs(job)
        job.outgoing.each do |job_id|
          out = workflow.job(job_id)

          enqueue_job!(out) if out.ready_to_start?
        end
      end

  end

end
