module RaceExpectations
  # Small, inspectable least-squares model. Inputs and target are positions
  # normalised to [0, 1], so a 20-car race and a 22-car race are comparable.
  # Non-negative slopes prevent a worse input rank improving the expectation.
  class Regression
    FEATURES = %i[elo qualifying].freeze
    EPSILON = 1e-8

    def self.fit(samples, features: FEATURES)
      return if samples.empty?

      means = features.map { |key| samples.sum { |sample| sample.fetch(key) }.to_f / samples.size }
      mean_finish = samples.sum { |sample| sample.fetch(:finish) }.to_f / samples.size
      covariance = features.each_index.map do |i|
        features.each_index.map do |j|
          samples.sum { |sample| (sample.fetch(features[i]) - means[i]) * (sample.fetch(features[j]) - means[j]) }
        end
      end
      cross = features.each_index.map do |i|
        samples.sum { |sample| (sample.fetch(features[i]) - means[i]) * (sample.fetch(:finish) - mean_finish) }
      end

      weights = if features.one?
        [[cross.first / (covariance[0][0] + EPSILON), 0].max]
      else
        a = covariance[0][0] + EPSILON
        b = covariance[0][1]
        c = covariance[1][1] + EPSILON
        determinant = a * c - b * b
        left = (cross[0] * c - cross[1] * b) / determinant
        right = (cross[1] * a - cross[0] * b) / determinant
        if left.negative?
          [0, [cross[1] / c, 0].max]
        elsif right.negative?
          [[cross[0] / a, 0].max, 0]
        else
          [left, right]
        end
      end

      { intercept: mean_finish - weights.zip(means).sum { |weight, mean| weight * mean },
        weights: features.zip(weights).to_h }
    end

    def self.predict(model, sample)
      (model.fetch(:intercept) + model.fetch(:weights).sum { |key, weight| sample.fetch(key) * weight }).clamp(0, 1)
    end
  end
end
