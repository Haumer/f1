module Ai
  class RacePreview
    attr_reader :race

    def initialize(race)
      @race = race
    end

    def generate!
      context = build_context
      prompt = build_prompt(context)

      response = client.messages.create(
        model: "claude-sonnet-4-20250514",
        max_tokens: 4000,
        messages: [{ role: "user", content: prompt }]
      )

      content = response.content.first.text
      parsed = parse_response(content)

      analysis = race.ai_analyses.find_or_initialize_by(analysis_type: 'race_preview')
      analysis.update!(
        content: parsed[:content],
        picks: parsed[:picks],
        sources: parsed[:sources],
        generated_at: Time.current
      )
      analysis
    end

    private

    def client
      @client ||= Anthropic::Client.new(api_key: ENV['ANTHROPIC_API_KEY'])
    end

    def build_context
      {
        race_info: race_info,
        circuit_history: circuit_history,
        current_standings: current_standings,
        recent_form: recent_form,
        elo_rankings: elo_rankings,
        constructor_form: constructor_form
      }
    end

    def race_info
      circuit = race.circuit
      {
        name: circuit.name,
        circuit: circuit.name,
        location: "#{circuit.location}, #{circuit.country}",
        date: race.date.strftime("%B %d, %Y"),
        round: race.round,
        season: race.season.year
      }
    end

    def circuit_history
      circuit = race.circuit
      past_races = Race.where(circuit: circuit)
                       .where("date < ?", race.date)
                       .order(date: :desc)
                       .limit(5)
                       .includes(race_results: { driver: [], constructor: [] })

      past_races.map do |r|
        podium = r.race_results.sort_by { |rr| rr.position_order || 999 }.first(3)
        {
          year: r.season.year,
          podium: podium.map { |rr|
            {
              position: rr.position_order,
              driver: "#{rr.driver.forename} #{rr.driver.surname}",
              constructor: rr.constructor&.name
            }
          }
        }
      end
    end

    def current_standings
      season = race.season
      standings = season.latest_driver_standings&.first(10) || []
      standings.map do |ds|
        {
          position: ds.position,
          driver: "#{ds.driver.forename} #{ds.driver.surname}",
          points: ds.points&.round,
          wins: ds.wins || 0
        }
      end
    end

    def recent_form
      season = race.season
      drivers = season.season_drivers.includes(driver: [], constructor: [])

      # Get last 3 races before this one in the season
      recent_races = season.races.where("round < ?", race.round).order(round: :desc).limit(3)
      return [] if recent_races.empty?

      race_ids = recent_races.pluck(:id)
      results = RaceResult.where(race_id: race_ids)
                          .includes(:driver, :constructor, :status)
                          .group_by(&:driver_id)

      drivers.map do |sd|
        driver = sd.driver
        driver_results = results[driver.id] || []
        next if driver_results.empty?

        {
          driver: "#{driver.forename} #{driver.surname}",
          constructor: sd.constructor&.name,
          elo: driver.elo_v2&.round,
          recent_results: driver_results.map { |rr|
            {
              position: rr.position_order,
              status: rr.status&.status_type,
              points: rr.points.to_i
            }
          }
        }
      end.compact
    end

    def elo_rankings
      season = race.season
      drivers = season.season_drivers.includes(:driver, :constructor)
                      .sort_by { |sd| -(sd.driver.elo_v2 || 0) }
                      .first(10)

      drivers.map do |sd|
        {
          driver: "#{sd.driver.forename} #{sd.driver.surname}",
          constructor: sd.constructor&.name,
          elo: sd.driver.elo_v2&.round,
          peak_elo: sd.driver.peak_elo_v2&.round
        }
      end
    end

    def constructor_form
      season = race.season
      constructors = season.season_drivers.includes(:constructor).map(&:constructor).compact.uniq

      constructors.map do |c|
        {
          name: c.name,
          elo: c.elo&.round,
          peak_elo: c.peak_elo&.round
        }
      end.sort_by { |c| -(c[:elo] || 0) }
    end

    def build_prompt(context)
      <<~PROMPT
        You are an F1 analyst writing a race preview for f1elo.com — a data-driven F1 analytics site that tracks driver and constructor Elo ratings.

        Write an engaging, opinionated race preview for the upcoming race. Be bold with your predictions — don't hedge everything. Use the data provided but also apply your F1 knowledge about the circuit characteristics, team strengths, and current narratives.

        ## Race Information
        #{context[:race_info].to_json}

        ## Circuit History (Last 5 races here)
        #{context[:circuit_history].to_json}

        ## Current Championship Standings (Top 10)
        #{context[:current_standings].to_json}

        ## Recent Form (Last 3 races)
        #{context[:recent_form].to_json}

        ## Current Elo Rankings (Top 10)
        #{context[:elo_rankings].to_json}

        ## Constructor Elo Rankings
        #{context[:constructor_form].to_json}

        ## Instructions

        Structure your response EXACTLY as follows, using these section markers:

        ---CONTENT_START---
        Write the preview here in markdown format. Include:
        1. **Circuit Character** — What makes this track unique, what type of car/driver it favors
        2. **Form Guide** — Who's hot, who's not, based on recent results and Elo trends
        3. **Key Battles** — Championship implications, teammate rivalries, midfield fights
        4. **Prediction** — Your predicted top 5, with brief justification for each

        Reference specific Elo ratings and stats from the data when making arguments. Be specific, not generic.
        ---CONTENT_END---

        ---PICKS_START---
        Return a JSON object with your predictions:
        {
          "winner": "Driver Name",
          "podium": ["P1 Driver", "P2 Driver", "P3 Driver"],
          "top5": ["P1", "P2", "P3", "P4", "P5"],
          "fastest_lap": "Driver Name",
          "dark_horse": "Driver Name",
          "dnf_risk": "Driver Name"
        }
        ---PICKS_END---

        ---SOURCES_START---
        Return a JSON array of sources you referenced or recommend for further reading. Include URLs where possible:
        [
          {"title": "Source title", "url": "https://...", "type": "data|news|analysis"}
        ]
        Always include at least these data sources:
        - F1 Elo ratings from f1elo.com
        - Circuit history data from f1elo.com
        For any current-season news or developments you reference, note them as sources even without URLs.
        ---SOURCES_END---
      PROMPT
    end

    def parse_response(text)
      content = text[/---CONTENT_START---\s*(.*?)\s*---CONTENT_END---/m, 1] || text
      picks_raw = text[/---PICKS_START---\s*(.*?)\s*---PICKS_END---/m, 1]
      sources_raw = text[/---SOURCES_START---\s*(.*?)\s*---SOURCES_END---/m, 1]

      picks = begin
        JSON.parse(picks_raw || '{}')
      rescue JSON::ParserError
        {}
      end

      sources = begin
        JSON.parse(sources_raw || '[]')
      rescue JSON::ParserError
        []
      end

      { content: content.strip, picks: picks, sources: sources }
    end
  end
end
