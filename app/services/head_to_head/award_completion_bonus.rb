module HeadToHead
  # Grants a fixed cash bonus to a signed-in user for finishing an H2H session.
  # Once-per-year: if the user has already been awarded a bonus for any session
  # in the same season, this is a no-op. Guests and users without a fantasy
  # portfolio for the year are skipped.
  class AwardCompletionBonus
    BONUS_AMOUNT = 50

    Result = Struct.new(:granted, :amount, :reason, keyword_init: true) do
      def granted?; granted; end
    end

    def initialize(session)
      @session = session
    end

    def call
      return skip(:already_awarded) if @session.bonus_awarded_at.present?
      return skip(:no_user)         unless @session.user_id
      return skip(:not_finished)    unless @session.finished_at.present?

      user = @session.user
      return skip(:no_user)         unless user

      season = Season.find_by(year: @session.year.to_s)
      return skip(:no_season)       unless season

      portfolio = user.fantasy_portfolio_for(season)
      return skip(:no_portfolio)    unless portfolio

      if DriverPreferenceSession.where(user_id: user.id, year: @session.year).where.not(bonus_awarded_at: nil).exists?
        return skip(:already_awarded_this_year)
      end

      ActiveRecord::Base.transaction do
        portfolio.update!(cash: portfolio.cash + BONUS_AMOUNT)
        portfolio.transactions.create!(
          kind: "bonus",
          amount: BONUS_AMOUNT,
          note: "Head-to-Head completion bonus (#{@session.year})",
        )
        @session.update!(bonus_awarded_at: Time.current)
      end

      Result.new(granted: true, amount: BONUS_AMOUNT, reason: :awarded)
    end

    private

    def skip(reason)
      Result.new(granted: false, amount: 0, reason: reason)
    end
  end
end
