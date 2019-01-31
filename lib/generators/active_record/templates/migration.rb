class BurstCreate<%= table_name.camelize %> < ActiveRecord::Migration<%= migration_version %>
  def change
    create_table(:<%= table_name %>) do |t|
      t.string :name

      t.timestamps
    end

  end
end
