class CreateMatches < ActiveRecord::Migration[8.1]
  def change
    create_table :matches do |t|
      t.references :team1, null: false, foreign_key: { to_table: :teams }
      t.references :team2, null: false, foreign_key: { to_table: :teams }
      t.string :venue
      t.date :match_date
      t.references :winner, null: true, foreign_key: { to_table: :teams }
      t.integer :season
      t.references :toss_winner, null: true, foreign_key: { to_table: :teams }
      t.string :toss_decision

      t.timestamps
    end
  end
end
