# Production seed script for gridmind prediction + portfolio
# Run with: heroku run rails runner tmp/seed_prod_prediction.rb -a f1-elo

# === 1. Build driver ref → prod ID mapping ===
DRIVER_REFS = %w[
  antonelli bearman lawson bortoleto hadjar colapinto hamilton alonso
  gasly hulkenberg perez bottas max_verstappen sainz ocon stroll
  leclerc norris russell albon piastri arvid_lindblad
]

drivers = Driver.where(driver_ref: DRIVER_REFS).index_by(&:driver_ref)
missing = DRIVER_REFS - drivers.keys
abort "Missing drivers on prod: #{missing}" if missing.any?

# Local ID → driver_ref mapping (from local DB)
LOCAL_TO_REF = {
  24 => "antonelli", 34 => "bearman", 35 => "lawson", 36 => "bortoleto",
  40 => "hadjar", 41 => "colapinto", 42 => "hamilton", 45 => "alonso",
  494 => "gasly", 849 => "hulkenberg", 856 => "perez", 863 => "bottas",
  871 => "max_verstappen", 873 => "sainz", 880 => "ocon", 881 => "stroll",
  884 => "leclerc", 886 => "norris", 887 => "russell", 888 => "albon",
  897 => "piastri", 899 => "arvid_lindblad"
}

def remap_driver_id(local_id, drivers)
  ref = LOCAL_TO_REF[local_id]
  abort "No ref mapping for local driver #{local_id}" unless ref
  drivers[ref]&.id || abort("Driver #{ref} not found on prod")
end

# === 2. Look up race, season, circuit, constructor ===
season = Season.find_by!(year: "2026")
race = Race.joins(:season).where(seasons: { year: "2026" }, round: 1).first!
circuit = Circuit.find_by!(circuit_ref: "albert_park")
mercedes = Constructor.find_by!(constructor_ref: "mercedes")

# Inline link races: local_id => [year, round]
RACE_LOOKUPS = {
  1108 => ["2022", 3],  # 2022 Australian GP
  25   => ["2025", 1],  # 2025 Australian GP
  1130 => ["2023", 3],  # 2023 Australian GP
  1152 => ["2024", 3],  # 2024 Australian GP
  1    => ["2026", 1],  # 2026 Australian GP (the current race)
}

race_id_map = {}
RACE_LOOKUPS.each do |local_id, (year, round)|
  r = Race.joins(:season).where(seasons: { year: year }, round: round).first
  abort "Race not found: year=#{year} round=#{round} (local #{local_id})" unless r
  race_id_map[local_id] = r.id
end

circuit_id_map = { 26 => circuit.id }

# === 3. Remap inline links in reasoning text ===
def remap_links(text, race_id_map, circuit_id_map, drivers)
  return text if text.blank?

  # Remap /races/LOCAL_ID
  text = text.gsub(%r{/races/(\d+)}) do |match|
    local_id = $1.to_i
    if race_id_map[local_id]
      "/races/#{race_id_map[local_id]}"
    else
      match
    end
  end

  # Remap /circuits/LOCAL_ID
  text = text.gsub(%r{/circuits/(\d+)}) do |match|
    local_id = $1.to_i
    if circuit_id_map[local_id]
      "/circuits/#{circuit_id_map[local_id]}"
    else
      match
    end
  end

  # Remap /drivers/LOCAL_ID
  text = text.gsub(%r{/drivers/(\d+)}) do |match|
    local_id = $1.to_i
    ref = LOCAL_TO_REF[local_id]
    if ref && drivers[ref]
      "/drivers/#{drivers[ref].id}"
    else
      match
    end
  end

  text
end

# === 4. Build remapped predicted_results ===
predicted_results = [
  {"grid":1,"signals":["long"],"position":1,"driver_id":887,"reasoning":"Pole at a track where he's finished P3 twice ({2022|/races/1108}, {2025|/races/25}). Mercedes testing pace was dominant. Pole conversion rate at {Albert Park|/circuits/26} is historically high — safest win bet on the grid.","confidence":65},
  {"grid":2,"signals":["buy","long"],"position":2,"driver_id":24,"reasoning":"P4 {here in 2025|/races/25} as a rookie in his first Albert Park start. Now has a year of experience in the fastest car. At {2214 EC|/drivers/24} with a 226-point gap to teammate Russell, every race near the front closes that inefficiency fast.","confidence":50},
  {"grid":6,"signals":[],"position":3,"driver_id":886,"reasoning":"Won {here in 2025|/races/25} and has the best {Albert Park|/circuits/26} average on the grid — P5.4 over 5 races with zero DNFs. McLaren race pace always gains from grid. P6 to P3 is conservative for him.","confidence":35},
  {"grid":5,"signals":[],"position":4,"driver_id":897,"confidence":30},
  {"grid":4,"signals":[],"position":5,"driver_id":884,"confidence":25},
  {"grid":7,"signals":[],"position":6,"driver_id":42,"confidence":30},
  {"grid":20,"signals":[],"position":7,"driver_id":871,"reasoning":"P1 in the last three 2025 races. Went P19 to P2 {here last year|/races/25} and won from the front in {2023|/races/1130}. But P20 grid is deep and the EC math is brutal — even P7 costs him -40. Tempting short, but shorting the highest-rated driver ({2553 EC|/drivers/871}) when he has a history of Albert Park comebacks is reckless.","confidence":40},
  {"grid":3,"signals":["buy"],"position":8,"driver_id":40,"reasoning":"P3 grid but only one Albert Park start — P20 {in 2025|/races/25} in a weaker RB car. Now in a Red Bull but no circuit knowledge. Drops to P8 but at {2066 EC|/drivers/40}, finishing P8 against a field averaging 2100+ generates massive pairwise gains.","confidence":25},
  {"grid":8,"signals":[],"position":9,"driver_id":35,"reasoning":"Third-highest EC gainer at +47. But at {2051 EC|/drivers/35} he's nearly the same price as {Hadjar|/drivers/40} (2066) while gaining less. Hadjar is strictly better value for the second roster slot.","confidence":25},
  {"grid":11,"signals":[],"position":10,"driver_id":849,"reasoning":"Five {Albert Park|/circuits/26} races: P7, P9, P7, P7, P7. The most consistent circuit specialist on the grid. Audi's 2026 car is an unknown though, and +38 EC is less than half the roster picks. Worth monitoring.","confidence":40},
  {"grid":12,"signals":[],"position":11,"driver_id":34,"confidence":20},
  {"grid":9,"signals":[],"position":12,"driver_id":899,"confidence":15},
  {"grid":13,"signals":[],"position":13,"driver_id":880,"confidence":20},
  {"grid":10,"signals":[],"position":14,"driver_id":36,"confidence":20},
  {"grid":15,"signals":[],"position":15,"driver_id":888,"confidence":20},
  {"grid":14,"signals":[],"position":16,"driver_id":494,"confidence":20},
  {"grid":16,"signals":[],"position":17,"driver_id":41,"confidence":20},
  {"grid":nil,"signals":[],"position":18,"driver_id":881,"reasoning":"P6 average over the last 3 years here — remarkable circuit specialist. But Aston Martin's 2026 car is 4.5s off pace. At -32 EC the loss is too small to justify a short position over the three above.","confidence":20},
  {"grid":19,"signals":[],"position":19,"driver_id":863,"confidence":25},
  {"grid":18,"signals":["short"],"position":20,"driver_id":856,"reasoning":"Historical avg P7.2 at {Albert Park|/circuits/26} across 5 races — but all with Red Bull or Force India. Cadillac is a brand new constructor with zero race pedigree. P18 grid, nowhere to go.","confidence":25},
  {"grid":17,"signals":["short"],"position":21,"driver_id":45,"reasoning":"P3 {here in 2023|/races/1130} when Aston Martin were competitive. P17 {in 2025|/races/25} when they weren't. At {2134 EC|/drivers/45} with a 432-point gap to his 2566 peak, the decline is structural and still accelerating.","confidence":35},
  {"grid":nil,"signals":["short"],"position":22,"driver_id":873,"reasoning":"Won {here in 2024|/races/1152} — with Ferrari. P18 {in 2025|/races/25} with Williams. No qualifying time means pit lane start. Williams are dead last on race pace. The car, not the driver, is the anchor.","confidence":40}
].map do |entry|
  entry = entry.transform_keys(&:to_s)
  entry["driver_id"] = remap_driver_id(entry["driver_id"], drivers)
  entry["reasoning"] = remap_links(entry["reasoning"], race_id_map, circuit_id_map, drivers) if entry["reasoning"]
  entry
end

# === 5. Build remapped elo_changes ===
elo_changes_local = {
  "24"=>{"diff"=>77.2,"new_elo"=>2291.2,"old_elo"=>2214.0},
  "34"=>{"diff"=>9.5,"new_elo"=>2123.2,"old_elo"=>2113.7},
  "35"=>{"diff"=>47.4,"new_elo"=>2098.6,"old_elo"=>2051.2},
  "36"=>{"diff"=>8.0,"new_elo"=>2010.4,"old_elo"=>2002.4},
  "40"=>{"diff"=>53.9,"new_elo"=>2120.0,"old_elo"=>2066.1},
  "41"=>{"diff"=>2.7,"new_elo"=>1896.0,"old_elo"=>1893.3},
  "42"=>{"diff"=>36.2,"new_elo"=>2246.6,"old_elo"=>2210.4},
  "45"=>{"diff"=>-100.9,"new_elo"=>2033.6,"old_elo"=>2134.5},
  "494"=>{"diff"=>2.3,"new_elo"=>1943.3,"old_elo"=>1941.0},
  "849"=>{"diff"=>38.1,"new_elo"=>2084.9,"old_elo"=>2046.8},
  "856"=>{"diff"=>-74.1,"new_elo"=>2000.3,"old_elo"=>2074.3},
  "863"=>{"diff"=>-21.3,"new_elo"=>1885.9,"old_elo"=>1907.2},
  "871"=>{"diff"=>-39.8,"new_elo"=>2513.4,"old_elo"=>2553.2},
  "873"=>{"diff"=>-109.5,"new_elo"=>2018.2,"old_elo"=>2127.7},
  "880"=>{"diff"=>-1.1,"new_elo"=>2074.4,"old_elo"=>2075.5},
  "881"=>{"diff"=>-32.1,"new_elo"=>1963.1,"old_elo"=>1995.2},
  "884"=>{"diff"=>19.1,"new_elo"=>2346.2,"old_elo"=>2327.1},
  "886"=>{"diff"=>19.9,"new_elo"=>2451.4,"old_elo"=>2431.4},
  "887"=>{"diff"=>39.4,"new_elo"=>2479.3,"old_elo"=>2439.8},
  "888"=>{"diff"=>-18.1,"new_elo"=>2042.9,"old_elo"=>2061.0},
  "897"=>{"diff"=>13.4,"new_elo"=>2422.2,"old_elo"=>2408.7},
  "899"=>{"diff"=>29.5,"new_elo"=>2029.5,"old_elo"=>2000.0}
}

elo_changes = {}
elo_changes_local.each do |local_id_str, data|
  prod_id = remap_driver_id(local_id_str.to_i, drivers)
  elo_changes[prod_id.to_s] = data
end

# === 6. Sources (remap internal URLs) ===
sources = [
  {"url" => "/elo", "type" => "internal", "title" => "Elo Rankings"},
  {"url" => "/races/#{race.id}", "type" => "internal", "title" => "2026 Australian GP"},
  {"url" => "/circuits/#{circuit.id}", "type" => "internal", "title" => "Albert Park Circuit"},
  {"url" => "/drivers/#{drivers['antonelli'].id}", "type" => "internal", "title" => "Andrea Kimi Antonelli"},
  {"url" => "/drivers/#{drivers['hadjar'].id}", "type" => "internal", "title" => "Isack Hadjar"},
  {"url" => "/drivers/#{drivers['russell'].id}", "type" => "internal", "title" => "George Russell"},
  {"url" => "/drivers/#{drivers['sainz'].id}", "type" => "internal", "title" => "Carlos Sainz"},
  {"url" => "/drivers/#{drivers['alonso'].id}", "type" => "internal", "title" => "Fernando Alonso"},
  {"url" => "/drivers/#{drivers['perez'].id}", "type" => "internal", "title" => "Sergio Pérez"},
]

# === 7. Fantasy picks (no ID remapping needed, uses names) ===
fantasy_picks = {
  "longs" => [
    {"price" => 243.98, "driver" => "George Russell", "shares" => 6, "predicted_pos" => 1, "expected_dividend" => 5.0},
    {"price" => 221.4, "driver" => "Andrea Kimi Antonelli", "shares" => 5, "predicted_pos" => 2, "expected_dividend" => 3.0}
  ],
  "roster" => [
    {"elo" => 2214.0, "driver" => "Andrea Kimi Antonelli", "expected_gain" => 77.2, "predicted_pos" => 2},
    {"elo" => 2066.1, "driver" => "Isack Hadjar", "expected_gain" => 53.9, "predicted_pos" => 8}
  ],
  "shorts" => [
    {"price" => 212.77, "driver" => "Carlos Sainz", "shares" => 3, "expected_drop" => -109.5, "predicted_pos" => 22},
    {"price" => 213.45, "driver" => "Fernando Alonso", "shares" => 3, "expected_drop" => -100.9, "predicted_pos" => 21},
    {"price" => 207.43, "driver" => "Sergio Pérez", "shares" => 3, "expected_drop" => -74.1, "predicted_pos" => 20}
  ],
  "summary" => "Roster: Antonelli + Hadjar for +131 combined EC. Long Russell at P1 for the 5/share dividend. Shorting Sainz, Alonso, Pérez into -285 combined EC loss.",
  "projection" => "If this lands: Antonelli gains +77.2 EC (net ~76 after 1% sell fee). Hadjar gains +53.9 EC (net ~53 after 1% sell fee). Russell long pays 30 in win dividends (6x 5.0/share). Antonelli long pays 15 in podium dividends (5x 3.0/share). Shorts capture proportional downside across 3 positions. Net expected portfolio gain: ~431 EC equivalent."
}

analysis = "Mercedes lock out the front row and Russell converts pole — this is a circuit where qualifying position holds. The Elo Cash value is in the chasers: Antonelli and Hadjar are underpriced relative to their finishing positions, while Sainz and Alonso are in cars that amplify their decline every race."

# === 8. Create user + portfolios ===
ActiveRecord::Base.transaction do
  user = User.find_or_initialize_by(username: "gridmind")
  if user.new_record?
    user.email = "gridmind@f1elo.com"
    user.password = ENV.fetch("GRIDMIND_PASSWORD") { SecureRandom.hex(16) }
    user.save!
    puts "Created user: #{user.username} (id: #{user.id})"
  else
    puts "User already exists: #{user.username} (id: #{user.id})"
  end

  # Roster portfolio
  rp = user.fantasy_portfolio_for(season)
  unless rp
    rp = Fantasy::CreatePortfolio.new(user: user, season: season).call
    puts "Created roster portfolio (id: #{rp.id})"
  end

  # Stock portfolio
  sp = user.fantasy_stock_portfolio_for(season)
  unless sp
    sp = FantasyStockPortfolio.create!(user: user, season: season, cash: rp.starting_capital)
    puts "Created stock portfolio (id: #{sp.id})"
  end

  # Constructor support
  cs = ConstructorSupport.find_or_create_by!(user: user, season: season) do |s|
    s.constructor = mercedes
  end
  puts "Constructor support: #{mercedes.constructor_ref} (id: #{cs.id})"

  # === 9. Execute trades ===
  # Roster buys
  %w[antonelli hadjar].each do |ref|
    driver = drivers[ref]
    existing = rp.roster_entries.joins(:driver).where(drivers: { driver_ref: ref }).first
    unless existing
      result = Fantasy::BuyDriver.new(portfolio: rp, driver: driver, race: race).call
      puts "Bought #{ref} for roster: #{result.inspect}"
    else
      puts "Already on roster: #{ref}"
    end
  end

  # Stock longs
  [["russell", 6], ["antonelli", 5]].each do |ref, shares|
    driver = drivers[ref]
    existing = sp.holdings.joins(:driver).where(drivers: { driver_ref: ref }, direction: "long").first
    unless existing
      result = Fantasy::Stock::BuyShares.new(portfolio: sp, driver: driver, shares: shares, race: race).call
      puts "Long #{shares} shares of #{ref}: #{result.inspect}"
    else
      puts "Already long: #{ref}"
    end
  end

  # Stock shorts
  [["sainz", 3], ["alonso", 3], ["perez", 3]].each do |ref, shares|
    driver = drivers[ref]
    existing = sp.holdings.joins(:driver).where(drivers: { driver_ref: ref }, direction: "short").first
    unless existing
      result = Fantasy::Stock::OpenShort.new(portfolio: sp, driver: driver, shares: shares, race: race).call
      puts "Short #{shares} shares of #{ref}: #{result.inspect}"
    else
      puts "Already short: #{ref}"
    end
  end

  # === 10. Create prediction ===
  prediction = Prediction.find_or_initialize_by(user: user, race: race)
  prediction.assign_attributes(
    predicted_results: predicted_results,
    elo_changes: elo_changes,
    fantasy_picks: fantasy_picks,
    sources: sources,
    analysis: analysis
  )
  prediction.save!
  puts "Prediction saved (id: #{prediction.id})"
  puts "View at: /predictions/#{prediction.id}"
end

puts "\nDone!"
