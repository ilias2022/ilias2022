class RemoveWinsLossesFromTeams < ActiveRecord::Migration[8.1]
  def change
    remove_column :teams, :wins, :integer
    remove_column :teams, :losses, :integer
  end
end
