namespace :og do
  desc "Generate OG preview images locally. Usage: rake og:previews[round] or rake og:previews (next race)"
  task :previews, [:round] => :environment do |_t, args|
    season = Season.sorted_by_year.first
    race = if args[:round]
             season.races.find_by!(round: args[:round])
           else
             season.next_race || season.races.order(round: :desc).first
           end

    predictions = Prediction.where(race: race).includes(:user)
    if predictions.empty?
      puts "No predictions found for Round #{race.round} (#{race.circuit.name})"
      exit
    end

    predictions.each do |prediction|
      output = Rails.root.join("public", "og-preview-#{prediction.user.username}-r#{race.round}.png")
      tempfile = OgPreviewGenerator.new(prediction).generate
      FileUtils.cp(tempfile.path, output)
      tempfile.close
      tempfile.unlink
      puts "Generated: #{output.basename}"
    end
  end
end
