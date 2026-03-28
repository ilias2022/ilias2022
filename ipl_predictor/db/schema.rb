# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_03_28_080634) do
  create_table "matches", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "match_date"
    t.integer "season"
    t.integer "team1_id", null: false
    t.integer "team2_id", null: false
    t.string "toss_decision"
    t.integer "toss_winner_id"
    t.datetime "updated_at", null: false
    t.string "venue"
    t.integer "winner_id"
    t.index ["team1_id"], name: "index_matches_on_team1_id"
    t.index ["team2_id"], name: "index_matches_on_team2_id"
    t.index ["toss_winner_id"], name: "index_matches_on_toss_winner_id"
    t.index ["winner_id"], name: "index_matches_on_winner_id"
  end

  create_table "predictions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "predicted_winner_id"
    t.integer "team1_id", null: false
    t.float "team1_win_probability"
    t.integer "team2_id", null: false
    t.float "team2_win_probability"
    t.datetime "updated_at", null: false
    t.string "venue"
    t.index ["predicted_winner_id"], name: "index_predictions_on_predicted_winner_id"
    t.index ["team1_id"], name: "index_predictions_on_team1_id"
    t.index ["team2_id"], name: "index_predictions_on_team2_id"
  end

  create_table "teams", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "home_ground"
    t.string "name"
    t.string "short_name"
    t.integer "titles"
    t.datetime "updated_at", null: false
  end

  add_foreign_key "matches", "teams", column: "team1_id"
  add_foreign_key "matches", "teams", column: "team2_id"
  add_foreign_key "matches", "teams", column: "toss_winner_id"
  add_foreign_key "matches", "teams", column: "winner_id"
  add_foreign_key "predictions", "teams", column: "predicted_winner_id"
  add_foreign_key "predictions", "teams", column: "team1_id"
  add_foreign_key "predictions", "teams", column: "team2_id"
end
