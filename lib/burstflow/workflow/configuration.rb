module Burstflow

module Workflow::Configuration
  extend ActiveSupport::Concern

  included do |_klass|
    def configure(*args)
      builder = Builder.new()
      builder.instance_exec *args, &self.class.configuration
      builder.resolve_dependencies
      builder.as_json
    end
  end

  class_methods do
    def define_flow_attributes(*keys)
      keys.each do |key|
        define_method key.to_sym do
          return flow[key.to_s]
        end

        define_method "#{key}=".to_sym do |v|
          return flow[key.to_s] = v
        end
      end
    end

    def configure(&block)
      @configuration = block
    end

    def configuration
      @configuration
    end
  end

end

end