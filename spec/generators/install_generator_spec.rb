require 'spec_helper'
require 'generator_spec'
require 'tmpdir'

require 'generators/burstflow/install/install_generator'

module Burstflow

  module Generators

    describe InstallGenerator, type: :generator do
      root_dir = File.expand_path(Dir.tmpdir, __FILE__)
      destination root_dir

      before :all do
        prepare_destination
        run_generator
      end

      it 'creates the installation db migration' do
        migration_file =
          Dir.glob("#{root_dir}/db/migrate/*create_workflow.rb")

        assert_file migration_file[0],
                    /CreateWorkflow < ActiveRecord::Migration/
      end
    end

  end

end
