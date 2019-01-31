module Burstflow

  module Generators

    class BurstGenerator < Rails::Generators::NamedBase

      Rails::Generators::ResourceHelpers

      source_root File.expand_path('templates', __dir__)
      argument :workflow_cname, type: :string, default: 'Burst::Workflow'

      namespace :burst
      hook_for :orm, required: true

      desc 'Generates a model with the given NAME and a migration file.'

      def self.start(args, config)
        workflow_cname = args.size > 1 ? args[1] : 'Burst::Workflow'
        args.insert(1, workflow_cname)
        super
      end

      def inject_user_class
        invoke 'rolify:user', [user_cname, class_name], orm: options.orm
      end

      def copy_initializer_file
        template 'initializer.rb', 'config/initializers/burst.rb'
      end

      def show_readme
        readme 'README' if behavior == :invoke
      end

    end

  end

end
