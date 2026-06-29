namespace :fantasy do
  desc "Backfill fantasy portfolios for users who don't have one in the current season"
  task backfill_portfolios: :environment do
    season = Season.sorted_by_year.first
    abort "No season found" unless season

    users = User.left_joins(:fantasy_portfolios)
                .where("fantasy_portfolios.id IS NULL OR fantasy_portfolios.season_id <> ?", season.id)
                .distinct

    created = 0
    skipped = 0
    failed  = 0

    users.find_each do |user|
      if user.fantasy_portfolio_for(season)
        skipped += 1
        next
      end

      result = Fantasy::CreatePortfolio.new(user: user, season: season).call
      if result[:error]
        failed += 1
        puts "  ✗ #{user.username}: #{result[:error]}"
      else
        created += 1
        puts "  ✓ #{user.username}"
      end
    rescue => e
      failed += 1
      puts "  ✗ #{user.username}: #{e.class}: #{e.message}"
    end

    puts ""
    puts "Backfill complete: #{created} created, #{skipped} skipped, #{failed} failed (season: #{season.year})"
  end
end
