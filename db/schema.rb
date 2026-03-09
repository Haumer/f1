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

ActiveRecord::Schema[7.0].define(version: 2026_03_09_070551) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "admin_alerts", force: :cascade do |t|
    t.string "title", null: false
    t.text "message"
    t.string "severity", default: "error"
    t.string "source"
    t.boolean "resolved", default: false
    t.datetime "resolved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_admin_alerts_on_created_at"
    t.index ["resolved"], name: "index_admin_alerts_on_resolved"
  end

  create_table "ahoy_events", force: :cascade do |t|
    t.bigint "visit_id"
    t.bigint "user_id"
    t.string "name"
    t.jsonb "properties"
    t.datetime "time"
    t.index ["name", "time"], name: "index_ahoy_events_on_name_and_time"
    t.index ["properties"], name: "index_ahoy_events_on_properties", opclass: :jsonb_path_ops, using: :gin
    t.index ["user_id"], name: "index_ahoy_events_on_user_id"
    t.index ["visit_id"], name: "index_ahoy_events_on_visit_id"
  end

  create_table "ahoy_visits", force: :cascade do |t|
    t.string "visit_token"
    t.string "visitor_token"
    t.bigint "user_id"
    t.string "ip"
    t.text "user_agent"
    t.text "referrer"
    t.string "referring_domain"
    t.text "landing_page"
    t.string "browser"
    t.string "os"
    t.string "device_type"
    t.string "country"
    t.string "region"
    t.string "city"
    t.float "latitude"
    t.float "longitude"
    t.string "utm_source"
    t.string "utm_medium"
    t.string "utm_term"
    t.string "utm_content"
    t.string "utm_campaign"
    t.string "app_version"
    t.string "os_version"
    t.string "platform"
    t.datetime "started_at"
    t.index ["user_id"], name: "index_ahoy_visits_on_user_id"
    t.index ["visit_token"], name: "index_ahoy_visits_on_visit_token", unique: true
    t.index ["visitor_token", "started_at"], name: "index_ahoy_visits_on_visitor_token_and_started_at"
  end

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
    t.index ["circuit_ref"], name: "index_circuits_on_circuit_ref"
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

  create_table "constructor_supports", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "constructor_id", null: false
    t.bigint "season_id", null: false
    t.boolean "active", default: true, null: false
    t.boolean "bonus_granted", default: false, null: false
    t.datetime "ended_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["constructor_id"], name: "index_constructor_supports_on_constructor_id"
    t.index ["season_id"], name: "index_constructor_supports_on_season_id"
    t.index ["user_id", "season_id", "active"], name: "idx_one_active_support_per_user_season", unique: true, where: "(active = true)"
    t.index ["user_id"], name: "index_constructor_supports_on_user_id"
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
    t.float "elo_v2"
    t.float "peak_elo_v2"
    t.index ["active"], name: "index_constructors_on_active"
    t.index ["constructor_ref"], name: "index_constructors_on_constructor_ref", unique: true
    t.index ["elo_v2"], name: "index_constructors_on_elo_v2"
  end

  create_table "countries", force: :cascade do |t|
    t.string "nationality"
    t.string "two_letter_country_code"
    t.string "name"
    t.string "three_letter_country_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "driver_badges", force: :cascade do |t|
    t.bigint "driver_id", null: false
    t.string "key", null: false
    t.string "label", null: false
    t.string "description"
    t.string "icon"
    t.string "color"
    t.string "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "tier"
    t.index ["driver_id", "key"], name: "index_driver_badges_on_driver_id_and_key", unique: true
    t.index ["driver_id"], name: "index_driver_badges_on_driver_id"
  end

  create_table "driver_countries", force: :cascade do |t|
    t.bigint "driver_id", null: false
    t.bigint "country_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["country_id"], name: "index_driver_countries_on_country_id"
    t.index ["driver_id"], name: "index_driver_countries_on_driver_id"
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
    t.integer "fourth_places"
    t.integer "fifth_places"
    t.integer "sixth_places"
    t.integer "seventh_places"
    t.integer "eighth_places"
    t.integer "nineth_places"
    t.integer "tenth_places"
    t.integer "outside_of_top_ten"
    t.integer "crash_races"
    t.integer "technichal_failures_races"
    t.integer "disqualified_races"
    t.integer "lapped_races"
    t.integer "finished_races"
    t.integer "fastest_laps"
    t.index ["driver_id"], name: "index_driver_standings_on_driver_id"
    t.index ["race_id", "driver_id"], name: "index_driver_standings_on_race_id_and_driver_id", unique: true
    t.index ["race_id"], name: "index_driver_standings_on_race_id"
    t.index ["season_end", "position"], name: "index_driver_standings_on_season_end_and_position", where: "(season_end = true)"
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
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "active", default: false
    t.string "skill"
    t.string "number_of_races"
    t.date "first_race_date"
    t.date "last_race_date"
    t.string "color", default: "#4B0082"
    t.float "lowest_elo"
    t.string "image_url"
    t.integer "podiums"
    t.integer "wins"
    t.integer "second_places"
    t.integer "third_places"
    t.integer "fourth_places"
    t.integer "fifth_places"
    t.integer "sixth_places"
    t.integer "seventh_places"
    t.integer "eighth_places"
    t.integer "nineth_places"
    t.integer "tenth_places"
    t.integer "outside_of_top_ten"
    t.integer "crash_races"
    t.integer "technichal_failures_races"
    t.integer "disqualified_races"
    t.integer "lapped_races"
    t.integer "finished_races"
    t.integer "fastest_laps"
    t.float "elo_v2"
    t.float "peak_elo_v2"
    t.string "wikipedia_image_url"
    t.index ["active"], name: "index_drivers_on_active"
    t.index ["driver_ref"], name: "index_drivers_on_driver_ref", unique: true
  end

  create_table "fantasy_achievements", force: :cascade do |t|
    t.bigint "fantasy_portfolio_id", null: false
    t.string "key"
    t.string "tier"
    t.datetime "earned_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["fantasy_portfolio_id", "key"], name: "index_fantasy_achievements_on_fantasy_portfolio_id_and_key", unique: true
    t.index ["fantasy_portfolio_id"], name: "index_fantasy_achievements_on_fantasy_portfolio_id"
  end

  create_table "fantasy_portfolios", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "season_id", null: false
    t.float "cash", default: 0.0, null: false
    t.float "starting_capital", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "roster_slots", default: 2, null: false
    t.index ["season_id"], name: "index_fantasy_portfolios_on_season_id"
    t.index ["user_id", "season_id"], name: "index_fantasy_portfolios_on_user_id_and_season_id", unique: true
    t.index ["user_id"], name: "index_fantasy_portfolios_on_user_id"
  end

  create_table "fantasy_roster_entries", force: :cascade do |t|
    t.bigint "fantasy_portfolio_id", null: false
    t.bigint "driver_id", null: false
    t.float "bought_at_elo", null: false
    t.bigint "bought_race_id"
    t.float "sold_at_elo"
    t.bigint "sold_race_id"
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bought_race_id"], name: "index_fantasy_roster_entries_on_bought_race_id"
    t.index ["driver_id"], name: "index_fantasy_roster_entries_on_driver_id"
    t.index ["fantasy_portfolio_id", "active"], name: "index_fantasy_roster_entries_on_fantasy_portfolio_id_and_active"
    t.index ["fantasy_portfolio_id", "driver_id"], name: "idx_unique_active_roster_entry", unique: true, where: "(active = true)"
    t.index ["fantasy_portfolio_id"], name: "index_fantasy_roster_entries_on_fantasy_portfolio_id"
    t.index ["sold_race_id"], name: "index_fantasy_roster_entries_on_sold_race_id"
  end

  create_table "fantasy_snapshots", force: :cascade do |t|
    t.bigint "fantasy_portfolio_id", null: false
    t.bigint "race_id", null: false
    t.float "value"
    t.float "cash"
    t.integer "rank"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["fantasy_portfolio_id", "race_id"], name: "index_fantasy_snapshots_on_fantasy_portfolio_id_and_race_id", unique: true
    t.index ["fantasy_portfolio_id"], name: "index_fantasy_snapshots_on_fantasy_portfolio_id"
    t.index ["race_id"], name: "index_fantasy_snapshots_on_race_id"
  end

  create_table "fantasy_stock_achievements", force: :cascade do |t|
    t.bigint "fantasy_stock_portfolio_id", null: false
    t.string "key"
    t.string "tier"
    t.datetime "earned_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["fantasy_stock_portfolio_id", "key"], name: "idx_stock_achievements_portfolio_key", unique: true
    t.index ["fantasy_stock_portfolio_id"], name: "index_fantasy_stock_achievements_on_fantasy_stock_portfolio_id"
  end

  create_table "fantasy_stock_holdings", force: :cascade do |t|
    t.bigint "fantasy_stock_portfolio_id", null: false
    t.bigint "driver_id", null: false
    t.integer "quantity", default: 1, null: false
    t.string "direction", null: false
    t.float "entry_price", null: false
    t.float "collateral", default: 0.0
    t.bigint "opened_race_id", null: false
    t.bigint "closed_race_id"
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["closed_race_id"], name: "index_fantasy_stock_holdings_on_closed_race_id"
    t.index ["driver_id"], name: "index_fantasy_stock_holdings_on_driver_id"
    t.index ["fantasy_stock_portfolio_id", "driver_id", "direction", "active"], name: "idx_stock_holdings_portfolio_driver_dir_active"
    t.index ["fantasy_stock_portfolio_id", "driver_id", "direction"], name: "idx_unique_active_stock_holding", unique: true, where: "(active = true)"
    t.index ["fantasy_stock_portfolio_id"], name: "index_fantasy_stock_holdings_on_fantasy_stock_portfolio_id"
    t.index ["opened_race_id"], name: "index_fantasy_stock_holdings_on_opened_race_id"
  end

  create_table "fantasy_stock_portfolios", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "season_id", null: false
    t.float "cash", default: 0.0, null: false
    t.float "starting_capital", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["season_id"], name: "index_fantasy_stock_portfolios_on_season_id"
    t.index ["user_id", "season_id"], name: "index_fantasy_stock_portfolios_on_user_id_and_season_id", unique: true
    t.index ["user_id"], name: "index_fantasy_stock_portfolios_on_user_id"
  end

  create_table "fantasy_stock_snapshots", force: :cascade do |t|
    t.bigint "fantasy_stock_portfolio_id", null: false
    t.bigint "race_id", null: false
    t.float "value"
    t.float "cash"
    t.integer "rank"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["fantasy_stock_portfolio_id", "race_id"], name: "idx_stock_snapshots_portfolio_race", unique: true
    t.index ["fantasy_stock_portfolio_id"], name: "index_fantasy_stock_snapshots_on_fantasy_stock_portfolio_id"
    t.index ["race_id"], name: "index_fantasy_stock_snapshots_on_race_id"
  end

  create_table "fantasy_stock_transactions", force: :cascade do |t|
    t.bigint "fantasy_stock_portfolio_id", null: false
    t.bigint "driver_id"
    t.bigint "race_id"
    t.string "kind", null: false
    t.integer "quantity"
    t.float "price"
    t.float "amount", null: false
    t.string "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["driver_id"], name: "index_fantasy_stock_transactions_on_driver_id"
    t.index ["fantasy_stock_portfolio_id"], name: "index_fantasy_stock_transactions_on_fantasy_stock_portfolio_id"
    t.index ["race_id"], name: "index_fantasy_stock_transactions_on_race_id"
  end

  create_table "fantasy_transactions", force: :cascade do |t|
    t.bigint "fantasy_portfolio_id", null: false
    t.string "kind", null: false
    t.float "amount", null: false
    t.bigint "driver_id"
    t.bigint "race_id"
    t.string "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["driver_id"], name: "index_fantasy_transactions_on_driver_id"
    t.index ["fantasy_portfolio_id"], name: "index_fantasy_transactions_on_fantasy_portfolio_id"
    t.index ["race_id"], name: "index_fantasy_transactions_on_race_id"
  end

  create_table "pg_search_documents", force: :cascade do |t|
    t.text "content"
    t.string "searchable_type"
    t.bigint "searchable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["searchable_type", "searchable_id"], name: "index_pg_search_documents_on_searchable"
  end

  create_table "predictions", force: :cascade do |t|
    t.bigint "race_id", null: false
    t.bigint "user_id", null: false
    t.jsonb "predicted_results", default: []
    t.jsonb "elo_changes", default: {}
    t.text "analysis"
    t.jsonb "fantasy_picks", default: {}
    t.jsonb "sources", default: []
    t.datetime "generated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["race_id", "user_id"], name: "index_predictions_on_race_id_and_user_id", unique: true
    t.index ["race_id"], name: "index_predictions_on_race_id"
    t.index ["user_id"], name: "index_predictions_on_user_id"
  end

  create_table "qualifying_results", force: :cascade do |t|
    t.bigint "race_id", null: false
    t.bigint "driver_id", null: false
    t.bigint "constructor_id"
    t.integer "position"
    t.string "q1"
    t.string "q2"
    t.string "q3"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["constructor_id"], name: "index_qualifying_results_on_constructor_id"
    t.index ["driver_id"], name: "index_qualifying_results_on_driver_id"
    t.index ["race_id"], name: "index_qualifying_results_on_race_id"
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
    t.integer "year"
    t.float "old_elo_v2"
    t.float "new_elo_v2"
    t.float "old_constructor_elo_v2"
    t.float "new_constructor_elo_v2"
    t.index ["constructor_id"], name: "index_race_results_on_constructor_id"
    t.index ["driver_id"], name: "index_race_results_on_driver_id"
    t.index ["position_order"], name: "index_race_results_on_position_order"
    t.index ["race_id", "driver_id"], name: "index_race_results_on_race_id_and_driver_id", unique: true
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
    t.string "time"
    t.string "fp1_time"
    t.string "fp2_time"
    t.string "fp3_time"
    t.string "quali_time"
    t.index ["circuit_id"], name: "index_races_on_circuit_id"
    t.index ["season_id", "date"], name: "index_races_on_season_id_and_date"
    t.index ["season_id", "round"], name: "index_races_on_season_id_and_round"
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
    t.index ["season_id", "driver_id"], name: "index_season_drivers_on_season_id_and_driver_id"
    t.index ["season_id"], name: "index_season_drivers_on_season_id"
  end

  create_table "seasons", force: :cascade do |t|
    t.string "year"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["year"], name: "index_seasons_on_year", unique: true
  end

  create_table "settings", force: :cascade do |t|
    t.string "key", null: false
    t.string "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_settings_on_key", unique: true
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "statuses", force: :cascade do |t|
    t.integer "kaggle_id"
    t.string "status_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.boolean "public_profile", default: true, null: false
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.datetime "terms_accepted_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
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
  add_foreign_key "constructor_supports", "constructors"
  add_foreign_key "constructor_supports", "seasons"
  add_foreign_key "constructor_supports", "users"
  add_foreign_key "driver_badges", "drivers"
  add_foreign_key "driver_countries", "countries"
  add_foreign_key "driver_countries", "drivers"
  add_foreign_key "driver_standings", "drivers"
  add_foreign_key "driver_standings", "races"
  add_foreign_key "fantasy_achievements", "fantasy_portfolios"
  add_foreign_key "fantasy_portfolios", "seasons"
  add_foreign_key "fantasy_portfolios", "users"
  add_foreign_key "fantasy_roster_entries", "drivers"
  add_foreign_key "fantasy_roster_entries", "fantasy_portfolios"
  add_foreign_key "fantasy_roster_entries", "races", column: "bought_race_id"
  add_foreign_key "fantasy_roster_entries", "races", column: "sold_race_id"
  add_foreign_key "fantasy_snapshots", "fantasy_portfolios"
  add_foreign_key "fantasy_snapshots", "races"
  add_foreign_key "fantasy_stock_achievements", "fantasy_stock_portfolios"
  add_foreign_key "fantasy_stock_holdings", "drivers"
  add_foreign_key "fantasy_stock_holdings", "fantasy_stock_portfolios"
  add_foreign_key "fantasy_stock_holdings", "races", column: "closed_race_id"
  add_foreign_key "fantasy_stock_holdings", "races", column: "opened_race_id"
  add_foreign_key "fantasy_stock_portfolios", "seasons"
  add_foreign_key "fantasy_stock_portfolios", "users"
  add_foreign_key "fantasy_stock_snapshots", "fantasy_stock_portfolios"
  add_foreign_key "fantasy_stock_snapshots", "races"
  add_foreign_key "fantasy_stock_transactions", "drivers"
  add_foreign_key "fantasy_stock_transactions", "fantasy_stock_portfolios"
  add_foreign_key "fantasy_stock_transactions", "races"
  add_foreign_key "fantasy_transactions", "drivers"
  add_foreign_key "fantasy_transactions", "fantasy_portfolios"
  add_foreign_key "fantasy_transactions", "races"
  add_foreign_key "predictions", "races"
  add_foreign_key "predictions", "users"
  add_foreign_key "qualifying_results", "constructors"
  add_foreign_key "qualifying_results", "drivers"
  add_foreign_key "qualifying_results", "races"
  add_foreign_key "race_results", "constructors"
  add_foreign_key "race_results", "drivers"
  add_foreign_key "race_results", "races"
  add_foreign_key "race_results", "statuses"
  add_foreign_key "races", "circuits"
  add_foreign_key "races", "seasons"
  add_foreign_key "season_drivers", "constructors"
  add_foreign_key "season_drivers", "drivers"
  add_foreign_key "season_drivers", "seasons"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
end
