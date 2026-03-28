class CreatePredictions < ActiveRecord::Migration[8.1]
  def change
    create_table :predictions do |t|
      t.references :team1, null: false, foreign_key: { to_table: :teams }
      t.references :team2, null: false, foreign_key: { to_table: :teams }
      t.string :venue
      t.float :team1_win_probability
      t.float :team2_win_probability
      t.references :predicted_winner, null: true, foreign_key: { to_table: :teams }

      t.timestamps
    end
  end
end
