require "test_helper"

class HeadToHead::AwardCompletionBonusTest < ActiveSupport::TestCase
  setup do
    @user = users(:codex)
    @season = seasons(:season_2026)
    @portfolio = FantasyPortfolio.find_or_create_by!(user: @user, season: @season) do |p|
      p.cash = 1000
      p.starting_capital = 1000
    end
    @session = DriverPreferenceSession.create!(
      user: @user,
      session_token: "t-#{SecureRandom.hex(4)}",
      year: @season.year.to_i,
      started_at: 1.minute.ago,
      finished_at: Time.current,
      rounds_target: 12,
      rounds_played: 12,
    )
  end

  test "grants the bonus and stamps the session" do
    starting_cash = @portfolio.cash
    result = HeadToHead::AwardCompletionBonus.new(@session).call
    assert result.granted?
    assert_equal HeadToHead::AwardCompletionBonus::BONUS_AMOUNT, result.amount
    assert_equal starting_cash + result.amount, @portfolio.reload.cash
    assert_not_nil @session.reload.bonus_awarded_at
    assert @portfolio.transactions.exists?(kind: "bonus")
  end

  test "no-op for guest sessions" do
    guest_session = DriverPreferenceSession.create!(
      session_token: "g-#{SecureRandom.hex(4)}",
      year: @season.year.to_i,
      started_at: 1.minute.ago,
      finished_at: Time.current,
      rounds_target: 12,
      rounds_played: 12,
    )
    result = HeadToHead::AwardCompletionBonus.new(guest_session).call
    refute result.granted?
    assert_equal :no_user, result.reason
  end

  test "no-op if already awarded this session" do
    HeadToHead::AwardCompletionBonus.new(@session).call
    result = HeadToHead::AwardCompletionBonus.new(@session.reload).call
    refute result.granted?
    assert_equal :already_awarded, result.reason
  end

  test "no-op if user already got a bonus for this year on another session" do
    HeadToHead::AwardCompletionBonus.new(@session).call
    later = DriverPreferenceSession.create!(
      user: @user,
      session_token: "t2-#{SecureRandom.hex(4)}",
      year: @season.year.to_i,
      started_at: 1.minute.ago,
      finished_at: Time.current,
      rounds_target: 12,
      rounds_played: 12,
    )
    result = HeadToHead::AwardCompletionBonus.new(later).call
    refute result.granted?
    assert_equal :already_awarded_this_year, result.reason
    assert_nil later.reload.bonus_awarded_at
  end
end
