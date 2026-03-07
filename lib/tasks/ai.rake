namespace :ai do
  desc "Generate race preview for the next upcoming race"
  task preview: :environment do
    today = Setting.effective_today
    season = Season.sorted_by_year.first

    race = season.races
                 .where("date >= ?", today)
                 .order(date: :asc)
                 .first

    if race.nil?
      puts "No upcoming race found."
      exit
    end

    puts "Generating preview for: #{race.circuit.name} (Round #{race.round}, #{race.date})"
    analysis = Ai::RacePreview.new(race).generate!
    puts "Preview generated! (#{analysis.content.length} chars)"
    puts "Picks: #{analysis.picks}"
    puts "Sources: #{analysis.sources.length} references"
  end

  desc "Generate race preview for a specific race ID"
  task :preview_for, [:race_id] => :environment do |_, args|
    race = Race.find(args[:race_id])
    puts "Generating preview for: #{race.circuit.name} (Round #{race.round}, #{race.date})"
    analysis = Ai::RacePreview.new(race).generate!
    puts "Preview generated! (#{analysis.content.length} chars)"
    puts "Picks: #{analysis.picks}"
  end
end
