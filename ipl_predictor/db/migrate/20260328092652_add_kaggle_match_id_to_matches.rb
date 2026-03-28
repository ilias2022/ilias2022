class AddKaggleMatchIdToMatches < ActiveRecord::Migration[8.1]
  def change
    add_column :matches, :kaggle_match_id, :integer
    add_index :matches, :kaggle_match_id
  end
end
