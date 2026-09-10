require "minitest/mock"

module RaceExpectationHistory
  # Synthetic independent input ranks for testing the calculation, not race
  # fixtures or reported real-world performance figures.
  def expectation_history(count: 45)
    Array.new(count) do |race_index|
      samples = Array.new(20) do |driver_index|
        elo = driver_index / 19.0
        qualifying = ((driver_index * 7 + race_index) % 20) / 19.0
        noise = ((driver_index + race_index) % 5 - 2) * 0.025
        { elo: elo, qualifying: qualifying, finish: (0.08 + 0.3 * elo + 0.5 * qualifying + noise).clamp(0, 1), field_size: 20 }
      end
      { id: race_index + 1, date: Date.new(2018, 1, 1) + race_index * 15, samples: samples }
    end
  end
end
