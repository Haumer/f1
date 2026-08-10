class SitemapsController < ApplicationController
  def index
    expires_in 6.hours, public: true

    host = ENV.fetch("APP_HOST", "f1elo.com")
    base = "https://#{host}"

    driver_ids = Driver.where(id: RaceResult.select(:driver_id).distinct).pluck(:id, :updated_at)
    seasons    = Season.pluck(:year, :updated_at)
    circuits   = Circuit.pluck(:circuit_ref, :updated_at)
    constructors = Constructor.pluck(:constructor_ref, :updated_at)
    races      = Race.joins(:season).pluck(:id, :updated_at)

    urls = []

    # Static / index pages
    [
      ['/',                            'weekly',  '1.0'],
      ['/elo',                         'weekly',  '0.9'],
      ['/about',                       'monthly', '0.5'],
      ['/head-to-head',                'weekly',  '0.8'],
      ['/drivers',                     'weekly',  '0.9'],
      ['/drivers/peak_elo',            'weekly',  '0.9'],
      ['/drivers/current_active_elo',  'weekly',  '0.9'],
      ['/drivers/compare',             'weekly',  '0.8'],
      ['/drivers/grid',                'weekly',  '0.7'],
      ['/races',                       'weekly',  '0.8'],
      ['/races/calendar',              'weekly',  '0.7'],
      ['/races/highest_elo',           'monthly', '0.7'],
      ['/races/podiums',               'monthly', '0.7'],
      ['/races/winners',               'monthly', '0.7'],
      ['/constructors',                'weekly',  '0.8'],
      ['/constructors/elo_rankings',   'weekly',  '0.8'],
      ['/constructors/best_pairings',  'monthly', '0.6'],
      ['/constructors/families',       'monthly', '0.5'],
      ['/seasons',                     'weekly',  '0.7'],
      ['/circuits',                    'weekly',  '0.6'],
      ['/stats',                       'weekly',  '0.7'],
      ['/stats/elo_milestones',        'monthly', '0.6'],
      ['/stats/badges',                'monthly', '0.6'],
      ['/stats/champion_timeline',     'monthly', '0.7'],
      ['/stats/race_wins',             'monthly', '0.6'],
      ['/stats/fan_standings',         'weekly',  '0.5'],
      ['/leaderboard',                 'weekly',  '0.5']
    ].each { |path, freq, prio| urls << { loc: "#{base}#{path}", changefreq: freq, priority: prio } }

    driver_ids.each do |id, updated|
      urls << { loc: "#{base}/drivers/#{id}", lastmod: updated&.iso8601, changefreq: 'weekly', priority: '0.7' }
    end

    seasons.each do |year, updated|
      urls << { loc: "#{base}/seasons/#{year}", lastmod: updated&.iso8601, changefreq: 'monthly', priority: '0.6' }
      urls << { loc: "#{base}/head-to-head/#{year}", changefreq: 'monthly', priority: '0.5' }
    end

    constructors.each do |ref, updated|
      urls << { loc: "#{base}/constructors/#{ref}", lastmod: updated&.iso8601, changefreq: 'monthly', priority: '0.6' }
    end

    circuits.each do |ref, updated|
      urls << { loc: "#{base}/circuits/#{ref}", lastmod: updated&.iso8601, changefreq: 'monthly', priority: '0.5' }
    end

    races.each do |id, updated|
      urls << { loc: "#{base}/races/#{id}", lastmod: updated&.iso8601, changefreq: 'monthly', priority: '0.6' }
    end

    @urls = urls
    render formats: :xml
  end
end
