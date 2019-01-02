module Burst::WorkflowHelper
  extend ActiveSupport::Concern

  class JSONBWithIndifferentAccess
    def self.dump(hash)
      hash.as_json
    end
  
    def self.load(hash)
      hash ||= {}
      hash = JSON.parse(hash) if hash.is_a? String
      hash.with_indifferent_access
    end
  end

  included do |klass|
    serialize :flow, JSONBWithIndifferentAccess

    def first_job
      all_jobs.min_by{ |n| n.started_at || Time.now.to_i }
    end
  
    def last_job
      all_jobs.max_by{ |n| n.finished_at || 0 } if finished?
    end

    def started_at
      first_job&.started_at
    end
  
    def finished_at
      last_job&.finished_at
    end

    def configure *args
      instance_exec *args, &self.class.configuration
    end

  end

  class_methods do 

    def define_flow_attributes *keys
      keys.each do |key|
        define_method key.to_sym do
          return self.flow[key.to_s]
        end

        define_method "#{key}=".to_sym do |v|
          return self.flow[key.to_s] = v
        end
      end
    end

    def configure &block
      @configuration = block
    end

    def configuration
      @configuration
    end
  end

end


# class Test
#   def self.configure &block
#     @c = block
#   end

#   def self.c
#     @c
#   end

#   def go
#     puts "111111"
#   end

#   def run
#     instance_eval &Test.c
#   end


# end