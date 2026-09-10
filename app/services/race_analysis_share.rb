require "digest"

# One public payload for metadata and the preview image. No account information
# is included. Fingerprinting the rendered data also catches corrected results
# and training data, even when the Race itself hasn't been touched.
class RaceAnalysisShare
  VERSION = "race-debrief-card-v2"

  attr_reader :analysis

  def initialize(analysis)
    @analysis = analysis
  end

  def title
    "#{analysis.race.circuit.name} #{analysis.race.year} · Race debrief"
  end

  def description
    report = analysis.expectations
    if report.assessed_count.positive?
      "Who beat expectations? Top 3, Flop 3 and the full-grid Elo + qualifying comparison. #{report.assessed_count}/#{analysis.rows.size} entrants assessed; DNFs excluded."
    else
      "Expectation rankings are unavailable with the current data. See race results, Elo changes and full-grid coverage; DNFs are not assessed."
    end
  end

  def url
    PublicSite.url(Rails.application.routes.url_helpers.race_path(analysis.race, anchor: "race-analysis"))
  end

  def payload
    @payload ||= {
      circuit: analysis.race.circuit.name, year: analysis.race.year, round: analysis.race.round,
      assessed: analysis.expectations.assessed_count, entrants: analysis.rows.size,
      top: entries(analysis.expectations.top_three), flop: entries(analysis.expectations.flop_three)
    }
  end

  def fingerprint
    Digest::SHA256.hexdigest([VERSION, RaceExpectations::Report::VERSION, payload].to_json)
  end

  private

  def entries(assessments)
    assessments.map do |assessment|
      { name: assessment.driver.fullname, expected: assessment.expected.round(1),
        finish: assessment.result.position_order, difference: assessment.difference.round(1) }
    end
  end
end
