module Burst::Builder
  extend ActiveSupport::Concern

  included do |klass|

    attr_accessor :build_deps, :build_jobs

    def initialize_builder
      @build_jobs = []
      @build_deps = []
    end

    def run klass, opts = {}
      opts = opts.with_indifferent_access

      before_deps = opts.delete(:before) || []
      after_deps = opts.delete(:after) || []

      job = klass.new(self, opts)
      build_jobs << job

      [*before_deps].each do |dep|
        build_deps << {from: job.id, to: dep.to_s }
      end

      [*after_deps].each do |dep|
        build_deps << {from: dep.to_s, to: job.id }
      end

      job.id
    end

    def lookup_job(id_or_klass)
      finded = build_jobs.select do |job|
        [job.id.to_s, job.klass.to_s].include?(id_or_klass.to_s)
      end
  
      raise "Duplicat job detected" if finded.count > 1
  
      finded.first
    end

    def resolve_dependencies
      build_deps.each do |dependency|
        from = lookup_job(dependency[:from])
        to   = lookup_job(dependency[:to])
  
        to.incoming << from.id
        from.outgoing << to.id
      end
    end

  end
end