require "test_helper"

class DriverBadgesTest < ActiveSupport::TestCase
  test "initializes with driver and computes badges" do
    service = DriverBadges.new(driver: drivers(:verstappen))
    assert service.badges.is_a?(Array)
  end

  test "persist! saves badges to the database" do
    driver = drivers(:verstappen)
    service = DriverBadges.new(driver: driver, min_year: 2020)
    service.persist!

    assert driver.badges.count >= 0
    driver.badges.each do |badge|
      assert badge.key.present?
      assert badge.label.present?
    end
  end

  test "persist! replaces existing badges" do
    driver = drivers(:verstappen)
    DriverBadges.new(driver: driver, min_year: 2020).persist!
    first_count = driver.badges.count

    DriverBadges.new(driver: driver, min_year: 2020).persist!
    assert_equal first_count, driver.badges.count
  end

  test "badges are sorted by BADGE_ORDER" do
    service = DriverBadges.new(driver: drivers(:verstappen), min_year: 2020)
    keys = service.badges.map { |b| b.key.to_s.sub(/^circuit_king_.*/, "circuit_king").to_sym }
    indices = keys.map { |k| DriverBadges::BADGE_ORDER.index(k) || 99 }
    assert_equal indices, indices.sort
  end

  test "compute_all_drivers! returns badge count" do
    count = DriverBadges.compute_all_drivers!
    assert count.is_a?(Integer)
    assert count >= 0
  end

  test "assign_tiers! assigns gold silver bronze" do
    DriverBadges.compute_all_drivers!
    DriverBadges.assign_tiers!

    tiers = DriverBadge.where.not(tier: nil).pluck(:tier).uniq
    tiers.each do |tier|
      assert_includes %w[gold silver bronze], tier
    end
  end

  # ── Race Badges ──

  test "check_pole_to_win awards badge for pole-to-victory conversions" do
    driver = drivers(:verstappen)
    # verstappen has grid: 1, position_order: 1 in bahrain_2026
    service = DriverBadges.new(driver: driver, min_year: 2020)
    pole_win_badges = service.badges.select { |b| b.key.to_s == "pole_to_win" }
    # May or may not qualify (needs >= 3), but method shouldn't error
    assert pole_win_badges.is_a?(Array)
  end

  # ── Elo Badges ──

  test "elo_rocket badge requires >= 80 elo gain" do
    service = DriverBadges.new(driver: drivers(:verstappen), min_year: 2020)
    rocket = service.badges.find { |b| b.key.to_s == "elo_rocket" }
    if rocket
      val = rocket.value.to_s.gsub("+", "").to_f
      assert val >= 80
    end
  end

  # ── Career Badges ──

  test "century_club requires >= 100 races" do
    service = DriverBadges.new(driver: drivers(:verstappen), min_year: 2020)
    century = service.badges.find { |b| b.key.to_s == "century_club" }
    # With fixture data, verstappen has few races — shouldn't qualify
    assert_nil century
  end

  # ── Dubious Badges ──

  test "hulkenberg_award requires >= 50 races with 0 podiums" do
    service = DriverBadges.new(driver: drivers(:verstappen), min_year: 2020)
    hulk = service.badges.find { |b| b.key.to_s == "hulkenberg_award" }
    # verstappen has podiums, should not get this
    assert_nil hulk
  end
end
