class CreateMatchScores < ActiveRecord::Migration[8.1]
  def change
    create_table :match_scores do |t|
      t.references :match, null: false, foreign_key: true
      t.references :team, null: false, foreign_key: true
      t.integer :runs_scored
      t.integer :wickets_lost

      t.timestamps
    end
  end
end
