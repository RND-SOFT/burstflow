module Burstflow

  module Workflow::Configuration

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

    included do |_klass|
      serialize :flow, JSONBWithIndifferentAccess

      def configure(*args)
        builder = Builder.new
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

      def options options
        @options ||= {}
        @options.merge! options
      end

      def opts
        @options ||= {}
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
