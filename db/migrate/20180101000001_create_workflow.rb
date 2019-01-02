class CreateWorkflow < ActiveRecord::Migration[5.1]
  def change
    enable_extension 'pgcrypto'

    create_table :burst_workflows, id: :uuid do |t|
      t.jsonb :flow, null: false, default: {}

      t.timestamps
    end
  end
end
