module EloRating
    @k_factor = Proc.new do |rating|
        8
    end

    def self.k_factor(rating = nil)
        @k_factor.call(rating)
    end

    def self.set_k_factor(&k_factor)
        k_factor.call(nil)
        @k_factor = k_factor
    rescue => e
        raise ArgumentError, "Error encountered in K-factor block when passed nil rating: #{e}"
    end

    def self.k_factor=(k_factor)
        @k_factor = Proc.new do
            k_factor
        end
    end

    def self.expected_score(player_rating, opponent_rating)
        1.0/(1 + (10 ** ((opponent_rating - player_rating)/400.0)))
    end

    def self.rating_adjustment(expected_score, actual_score, rating: nil, k_factor: nil)
        k_factor ||= k_factor(rating)
        k_factor * (actual_score - expected_score)
    end
end

class EloRating::Match
    attr_reader :players

    def initialize
        @players = []
    end

    def add_player(player_attributes)
        players << Player.new(player_attributes.merge(match: self))
        self
    end

    def updated_ratings
        validate_players!
        players.map(&:updated_rating)
    end

    private

    def validate_players!
        raise ArgumentError, 'Only one player can be the winner' if multiple_winners?
        raise ArgumentError, 'All players must have places if any do' if inconsistent_places?
    end

    def multiple_winners?
        players.select { |player| player.winner? }.size > 1
    end

    def inconsistent_places?
        players.select { |player| player.place }.any? &&
        players.select { |player| !player.place }.any?
    end

    class Player
    # :nodoc:
        attr_reader :rating, :place, :match, :race_result
        def initialize(attributes)
            validate_attributes!(rating: attributes[:rating], place: attributes[:place], winner: attributes[:winner])
            @race_result = attributes[:race_result]
            @match = attributes[:match]
            @rating = attributes[:rating]
            @place = attributes[:place]
            @winner = attributes[:winner]
        end

        def winner?
            @winner
        end

        def validate_attributes!(rating:, place:, winner:)
            raise ArgumentError, 'Rating must be numeric' unless rating.is_a? Numeric
            raise ArgumentError, 'Winner and place cannot both be specified' if place && winner
            raise ArgumentError, 'Place must be numeric' unless place.nil? || place.is_a?(Numeric)
        end

        def opponents
            match.players - [self]
        end

        def updated_rating
            { race_result: self.race_result, new_rating:(rating + total_rating_adjustments), old_rating: self.race_result.driver.elo, place: self.place }
        end

        def total_rating_adjustments
            opponents.map do |opponent|
                rating_adjustment_against(opponent)
            end.reduce(0, :+)
        end

        def rating_adjustment_against(opponent)
            EloRating.rating_adjustment(
                expected_score_against(opponent),
                actual_score_against(opponent),
                rating: rating
            )
        end

        def expected_score_against(opponent)
            EloRating.expected_score(rating, opponent.rating)
        end

        def actual_score_against(opponent)
            if won_against?(opponent)
                1
            elsif opponent.won_against?(self)
                0
            else # draw
                0.5
            end
        end

        def won_against?(opponent)
            winner? || placed_ahead_of?(opponent)
        end

        def placed_ahead_of?(opponent)
            if place && opponent.place
                place < opponent.place
            end
        end
    end
end

class EloRating::Race
    def initialize(race:)
        @match = EloRating::Match.new
        @race = race
        @results = @race.race_results
        add_all_drivers unless @race.driver_ratings.present?
    end

    def add_all_drivers
        @results.map do |result|
            @match.add_player(rating: result.driver.elo, place: result.position_order, race_result: result)
        end
        self
    end

    def preview_rating_changes
        @match.updated_ratings.each do |changes|
            { new: changes[:new_rating], old: changes[:old_rating], race_result: changes[:race_result]}
        end
        self
    end

    def update_driver_ratings
        puts @match.updated_ratings
        @match.updated_ratings.each do |changes|
            changes[:race_result].update(old_elo: changes[:old_rating], new_elo: changes[:new_rating])
            changes[:race_result].driver.update(elo: changes[:new_rating])
        end
        self
    end
end
