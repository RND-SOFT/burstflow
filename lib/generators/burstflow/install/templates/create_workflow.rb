class CreateWorkflow < ActiveRecord::Migration[5.1]

  def change
    enable_extension 'pgcrypto'

    create_table :burstflow_workflows, id: :uuid do |t|
      t.string :type, index: true
      t.string :status, index: true
      t.jsonb :flow, null: false, default: {}

      t.timestamps
    end
  end

end
