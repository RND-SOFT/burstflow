module Burstflow::Workflow::Callbacks

  extend  ActiveSupport::Concern
  include ActiveSupport::Callbacks

  included do
    define_callbacks :failure, :finish, :suspend, :resume
  end

  class_methods do
    def before_failure(*filters, &blk)
      set_callback(:failure, :before, *filters, &blk)
    end

    def after_failure(*filters, &blk)
      set_callback(:failure, :after, *filters, &blk)
    end

    def around_failure(*filters, &blk)
      set_callback(:failure, :around, *filters, &blk)
    end

    def before_finish(*filters, &blk)
      set_callback(:finish, :before, *filters, &blk)
    end

    def after_finish(*filters, &blk)
      set_callback(:finish, :after, *filters, &blk)
    end

    def around_finish(*filters, &blk)
      set_callback(:finish, :around, *filters, &blk)
    end

    def before_suspend(*filters, &blk)
      set_callback(:suspend, :before, *filters, &blk)
    end

    def after_suspend(*filters, &blk)
      set_callback(:suspend, :after, *filters, &blk)
    end

    def around_suspend(*filters, &blk)
      set_callback(:suspend, :around, *filters, &blk)
    end

    def before_resume(*filters, &blk)
      set_callback(:resume, :before, *filters, &blk)
    end

    def after_resume(*filters, &blk)
      set_callback(:resume, :after, *filters, &blk)
    end

    def around_resume(*filters, &blk)
      set_callback(:resume, :around, *filters, &blk)
    end
  end

end
