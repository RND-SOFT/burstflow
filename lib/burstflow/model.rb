module Burstflow::Model

  extend ActiveSupport::Concern

  included do |klass|
    klass.include ActiveModel::Model
    klass.include ActiveModel::Dirty
    klass.include ActiveModel::Serialization
    klass.extend ActiveModel::Callbacks

    attr_accessor :model

    def set_model(model)
      @model = model
    end

    def attributes=(hash)
      hash.each do |key, value|
        send("#{key}=", value)
      end
    end

    def ==(other)
      instance_variable_get('@model') == other.instance_variable_get('@model')
    end

    def as_json(*_args)
      serializable_hash
    end
  end

  class_methods do
    def define_stored_attributes(*keys)
      keys.each do |key|
        define_attribute_methods key.to_sym

        define_method key.to_sym do
          return @model[key.to_s]
        end

        define_method "#{key}=".to_sym do |v|
          send("#{key}_will_change!") if v != send(key)
          return @model[key.to_s] = v
        end
      end
    end
  end

end
