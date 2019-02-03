module Burstflow::Job::State

  extend ActiveSupport::Concern

  included do
    # mark job as enqueued when it is scheduled to queue
    def enqueue!
      raise Burstflow::Job::InternalError.new(self, "Can't enqueue: already enqueued") if enqueued?

      self.enqueued_at = current_timestamp
      self.started_at = nil
      self.finished_at = nil
      self.failed_at = nil
      self.suspended_at = nil
      self.resumed_at = nil
    end

    # mark job as started when it is start performing
    def start!
      raise Burstflow::Job::InternalError.new(self, "Can't start: already started") if started?
      raise Burstflow::Job::InternalError.new(self, "Can't start: not enqueued") unless enqueued?

      self.started_at = current_timestamp
    end

    # mark job as finished when it is finish performing
    def finish!
      raise Burstflow::Job::InternalError.new(self, "Can't finish: already finished") if finished?
      raise Burstflow::Job::InternalError.new(self, "Can't finish: not started") unless started?

      self.finished_at = current_timestamp
    end

    # mark job as failed when it is failed
    def fail!(msg_or_exception)
      # raise Burstflow::Job::InternalError.new(self, "Can't fail: already failed") if failed?
      # raise Burstflow::Job::InternalError.new(self, Can't fail: already finished") if finished?
      raise Burstflow::Job::InternalError.new(self, "Can't fail: not started") unless started?

      self.finished_at = self.failed_at = current_timestamp

      context = {}
      if msg_or_exception.is_a?(::Exception)
        context[:message]   = msg_or_exception.message
        context[:klass]     = msg_or_exception.class.to_s
        context[:backtrace] = msg_or_exception.backtrace.first(10)
        context[:cause]     = msg_or_exception.cause.try(:inspect)
      else
        context[:message]   = msg_or_exception
      end

      self.failure = context
    end

    # mark job as suspended
    def suspend!
      raise Burstflow::Job::InternalError.new(self, "Can't suspend: already suspended") if suspended?
      raise Burstflow::Job::InternalError.new(self, "Can't suspend: not runnig") unless running?

      self.suspended_at = current_timestamp
    end

    # mark job as resumed
    def resume!
      raise Burstflow::Job::InternalError.new(self, "Can't resume: already resumed") if resumed?
      raise Burstflow::Job::InternalError.new(self, "Can't resume: not suspended") unless suspended?

      self.resumed_at = current_timestamp
    end

    def enqueued?
      !enqueued_at.nil?
    end

    def started?
      !started_at.nil?
    end

    def finished?
      !finished_at.nil?
    end

    def running?
      started? && !finished? && !suspended?
    end

    def scheduled?
      enqueued? && !finished? && !suspended?
    end

    def failed?
      !failed_at.nil?
    end

    def suspended?
      !suspended_at.nil? && !resumed?
    end

    def resumed?
      !resumed_at.nil?
    end

    def succeeded?
      finished? && !failed?
    end

    def ready_to_start?
      !running? && !enqueued? && !finished? && !failed? && parents_succeeded?
    end

    def initial?
      incoming.empty?
    end

    def parents_succeeded?
      incoming.all? do |id|
        workflow.job(id).succeeded?
      end
    end

    def current_timestamp
      Time.now.to_i
    end
  end

  class_methods do
  end

end
