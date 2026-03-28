class CreatePlayerStats < ActiveRecord::Migration[8.1]
  def change
    create_table :player_stats do |t|
      t.string :player_name, null: false
      t.integer :season, null: false
      t.integer :matches_batted
      t.integer :total_runs
      t.integer :balls_faced
      t.integer :matches_bowled
      t.integer :wickets_taken
      t.integer :runs_conceded
      t.integer :balls_bowled

      t.timestamps
    end
  end
end
