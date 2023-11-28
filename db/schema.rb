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

ActiveRecord::Schema[7.0].define(version: 2023_11_28_165917) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "blazer_audits", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "query_id"
    t.text "statement"
    t.string "data_source"
    t.datetime "created_at"
    t.index ["query_id"], name: "index_blazer_audits_on_query_id"
    t.index ["user_id"], name: "index_blazer_audits_on_user_id"
  end

  create_table "blazer_checks", force: :cascade do |t|
    t.bigint "creator_id"
    t.bigint "query_id"
    t.string "state"
    t.string "schedule"
    t.text "emails"
    t.text "slack_channels"
    t.string "check_type"
    t.text "message"
    t.datetime "last_run_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_blazer_checks_on_creator_id"
    t.index ["query_id"], name: "index_blazer_checks_on_query_id"
  end

  create_table "blazer_dashboard_queries", force: :cascade do |t|
    t.bigint "dashboard_id"
    t.bigint "query_id"
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dashboard_id"], name: "index_blazer_dashboard_queries_on_dashboard_id"
    t.index ["query_id"], name: "index_blazer_dashboard_queries_on_query_id"
  end

  create_table "blazer_dashboards", force: :cascade do |t|
    t.bigint "creator_id"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_blazer_dashboards_on_creator_id"
  end

  create_table "blazer_queries", force: :cascade do |t|
    t.bigint "creator_id"
    t.string "name"
    t.text "description"
    t.text "statement"
    t.string "data_source"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_blazer_queries_on_creator_id"
  end

  create_table "circuits", force: :cascade do |t|
    t.integer "kaggle_id"
    t.string "circuit_ref"
    t.string "name"
    t.string "location"
    t.string "country"
    t.float "lat"
    t.float "lng"
    t.integer "alt"
    t.string "url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "constructor_standings", force: :cascade do |t|
    t.string "kaggle_id"
    t.bigint "race_id", null: false
    t.bigint "constructor_id", null: false
    t.float "points"
    t.integer "position"
    t.integer "wins"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["constructor_id"], name: "index_constructor_standings_on_constructor_id"
    t.index ["race_id"], name: "index_constructor_standings_on_race_id"
  end

  create_table "constructors", force: :cascade do |t|
    t.integer "kaggle_id"
    t.string "constructor_ref"
    t.string "name"
    t.string "nationality"
    t.string "url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "active"
    t.string "logo_url"
  end

  create_table "countries", force: :cascade do |t|
    t.string "nationality"
    t.string "two_letter_country_code"
    t.string "name"
    t.string "three_letter_country_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "driver_countries", force: :cascade do |t|
    t.bigint "driver_id", null: false
    t.bigint "country_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["country_id"], name: "index_driver_countries_on_country_id"
    t.index ["driver_id"], name: "index_driver_countries_on_driver_id"
  end

  create_table "driver_ratings", force: :cascade do |t|
    t.bigint "driver_id", null: false
    t.bigint "race_id", null: false
    t.integer "rating"
    t.boolean "peak_rating", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["driver_id"], name: "index_driver_ratings_on_driver_id"
    t.index ["race_id"], name: "index_driver_ratings_on_race_id"
  end

  create_table "driver_standings", force: :cascade do |t|
    t.string "kaggle_id"
    t.bigint "race_id", null: false
    t.bigint "driver_id", null: false
    t.float "points"
    t.integer "position"
    t.integer "wins"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "podiums"
    t.integer "second_places"
    t.integer "third_places"
    t.boolean "season_end"
    t.index ["driver_id"], name: "index_driver_standings_on_driver_id"
    t.index ["race_id"], name: "index_driver_standings_on_race_id"
  end

  create_table "drivers", force: :cascade do |t|
    t.integer "kaggle_id"
    t.string "driver_ref"
    t.integer "number"
    t.string "code"
    t.string "forename"
    t.string "surname"
    t.string "dob"
    t.string "nationality"
    t.string "url"
    t.float "elo"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "active", default: false
    t.string "skill"
    t.string "number_of_races"
    t.date "first_race_date"
    t.date "last_race_date"
    t.float "peak_elo"
    t.string "color", default: "#4B0082"
    t.float "lowest_elo"
    t.string "image_url"
  end

  create_table "race_results", force: :cascade do |t|
    t.integer "kaggle_id"
    t.bigint "race_id", null: false
    t.bigint "constructor_id", null: false
    t.bigint "driver_id", null: false
    t.integer "number"
    t.integer "grid"
    t.integer "position"
    t.integer "points"
    t.integer "position_order"
    t.string "time"
    t.string "milliseconds"
    t.integer "fastest_lap"
    t.integer "laps"
    t.string "fastest_lap_time"
    t.float "fastest_lap_speed"
    t.bigint "status_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.float "old_elo"
    t.float "new_elo"
    t.integer "year"
    t.index ["constructor_id"], name: "index_race_results_on_constructor_id"
    t.index ["driver_id"], name: "index_race_results_on_driver_id"
    t.index ["race_id"], name: "index_race_results_on_race_id"
    t.index ["status_id"], name: "index_race_results_on_status_id"
  end

  create_table "races", force: :cascade do |t|
    t.integer "kaggle_id"
    t.integer "year"
    t.integer "round"
    t.date "date"
    t.string "url"
    t.bigint "circuit_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.float "average_elo"
    t.bigint "season_id", null: false
    t.boolean "season_end"
    t.index ["circuit_id"], name: "index_races_on_circuit_id"
    t.index ["season_id"], name: "index_races_on_season_id"
  end

  create_table "season_drivers", force: :cascade do |t|
    t.bigint "driver_id", null: false
    t.bigint "season_id", null: false
    t.bigint "constructor_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "active"
    t.boolean "standin"
    t.index ["constructor_id"], name: "index_season_drivers_on_constructor_id"
    t.index ["driver_id"], name: "index_season_drivers_on_driver_id"
    t.index ["season_id"], name: "index_season_drivers_on_season_id"
  end

  create_table "seasons", force: :cascade do |t|
    t.string "year"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "statuses", force: :cascade do |t|
    t.integer "kaggle_id"
    t.string "status_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "videos", force: :cascade do |t|
    t.string "yt_id"
    t.string "embed_html"
    t.string "video_media_type"
    t.bigint "video_media_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["video_media_type", "video_media_id"], name: "index_videos_on_video_media"
  end

  add_foreign_key "constructor_standings", "constructors"
  add_foreign_key "constructor_standings", "races"
  add_foreign_key "driver_countries", "countries"
  add_foreign_key "driver_countries", "drivers"
  add_foreign_key "driver_ratings", "drivers"
  add_foreign_key "driver_ratings", "races"
  add_foreign_key "driver_standings", "drivers"
  add_foreign_key "driver_standings", "races"
  add_foreign_key "race_results", "constructors"
  add_foreign_key "race_results", "drivers"
  add_foreign_key "race_results", "races"
  add_foreign_key "race_results", "statuses"
  add_foreign_key "races", "circuits"
  add_foreign_key "races", "seasons"
  add_foreign_key "season_drivers", "constructors"
  add_foreign_key "season_drivers", "drivers"
  add_foreign_key "season_drivers", "seasons"
end
