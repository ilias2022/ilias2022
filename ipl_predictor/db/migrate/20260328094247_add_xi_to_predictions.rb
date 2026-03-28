class AddXiToPredictions < ActiveRecord::Migration[8.1]
  def change
    add_column :predictions, :xi_team1, :text
    add_column :predictions, :xi_team2, :text
  end
end
