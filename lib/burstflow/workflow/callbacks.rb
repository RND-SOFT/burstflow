module Burstflow::Workflow::Callbacks

  extend  ActiveSupport::Concern
  include ActiveSupport::Callbacks

  included do
    define_callbacks :failed, :cancelled, :succeeded, :finished, :suspend, :resume, :run

    create_callbacks [:failed, :cancelled, :succeeded, :finished, :suspend, :resume, :run]
  end

  class_methods do

    def create_callbacks list
      list.each do |name|
        define_singleton_method "before_#{name}".to_sym do |*filters, &blk|
          set_callback(name.to_sym, :before, *filters, &blk)
        end

        define_singleton_method "after_#{name}".to_sym do |*filters, &blk|
          set_callback(name.to_sym, :after, *filters, &blk)
        end

        define_singleton_method "around_#{name}".to_sym do |*filters, &blk|
          set_callback(name.to_sym, :around, *filters, &blk)
        end
      end
    end

  end

end
