module Burstflow::Job::Callbacks
  extend  ActiveSupport::Concern
  include ActiveJob::Callbacks

  included do

    define_callbacks :suspend
    define_callbacks :resume
    define_callbacks :failure

  end

  class_methods do

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

  
    def before_failure(*filters, &blk)
      set_callback(:failure, :before, *filters, &blk)
    end
  
    def after_failure(*filters, &blk)
      set_callback(:failure, :after, *filters, &blk)
    end
    
    def around_failure(*filters, &blk)
      set_callback(:failure, :around, *filters, &blk)
    end

  end

end