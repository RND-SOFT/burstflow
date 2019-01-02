module Burst::Builder
  extend ActiveSupport::Concern

  included do |klass|

    attr_accessor :build_deps

    def initialize_builder
      @build_deps = []
    end

    def run klass, opts = {}
      opts = opts.with_indifferent_access

      before_deps = opts.delete(:before) || []
      after_deps = opts.delete(:after) || []

      job = klass.new(self, opts)

      [*before_deps].each do |dep|
        build_deps << {from: job.id, to: dep.to_s }
      end

      [*after_deps].each do |dep|
        build_deps << {from: dep.to_s, to: job.id }
      end

      job_cache[job.id] = job
      jobs[job.id] = job.model

      job.id
    end

    def resolve_dependencies
      build_deps.each do |dependency|
        from = find_job(dependency[:from])
        to   = find_job(dependency[:to])

        to.incoming << from.id
        from.outgoing << to.id
      end
    end

  end
end