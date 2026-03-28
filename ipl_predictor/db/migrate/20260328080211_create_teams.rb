class CreateTeams < ActiveRecord::Migration[8.1]
  def change
    create_table :teams do |t|
      t.string :name
      t.string :short_name
      t.integer :wins
      t.integer :losses
      t.integer :titles
      t.string :home_ground

      t.timestamps
    end
  end
end
