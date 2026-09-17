require "test_helper"

class FantasyStockPortfoliosControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:codex)
    @portfolio = fantasy_stock_portfolios(:codex_stock_2026)
  end

  test "market requires authentication" do
    get market_fantasy_stock_portfolio_path(@portfolio)
    assert_response :redirect
  end

  test "market returns 200 for portfolio owner" do
    sign_in @user
    get market_fantasy_stock_portfolio_path(@portfolio)
    assert_response :success
  end

  test "market rules and deadline follow the settlement calculator" do
    sign_in @user
    race = races(:melbourne_2026)
    race.update!(date: 2.days.from_now.to_date)
    get market_fantasy_stock_portfolio_path(@portfolio)
    assert_select ".market-rules", text: /0\.25% of the entry value per race/
    assert_select ".market-rules", text: /0\.1 × the constructor multiplier/
    assert_select ".market-rules", text: /0\.02 credits per place/
    assert_select ".action-deadline time[datetime='#{(race.starts_at - 1.minute).iso8601}']"
    assert_select ".market-rules", text: /Reserve 50%/
  end

  test "quote is private read only and reflects prices funds and holdings" do
    sign_in @user
    races(:melbourne_2026).update!(date: 2.days.from_now.to_date)
    assert_no_difference "FantasyStockTransaction.count" do
      get market_fantasy_stock_portfolio_path(@portfolio, format: :json)
    end
    assert_response :success
    assert_equal "no-store", response.headers["Cache-Control"]
    quote = response.parsed_body
    assert quote["can_trade"]
    assert_in_delta @portfolio.available_cash, quote["cash"].to_f
    driver = quote["drivers"].find { |row| row["id"] == drivers(:norris).id }
    assert_equal ["short"], driver["owned"]
    assert_in_delta @portfolio.share_price(drivers(:norris)), driver["price"].to_f

    sign_out @user
    sign_in users(:latejoin)
    get market_fantasy_stock_portfolio_path(@portfolio, format: :json)
    assert_response :redirect
  end

  test "stale quote rolls back the entire draft without clearing it" do
    sign_in @user
    races(:melbourne_2026).update!(date: 2.days.from_now.to_date)
    wallet = @portfolio.wallet
    before_cash = wallet.cash
    before_quantity = fantasy_stock_holdings(:codex_ver_long).quantity
    assert_no_difference "FantasyStockTransaction.count" do
      post buy_batch_fantasy_stock_portfolio_path(@portfolio), params: { orders: [
        { driver_id: drivers(:verstappen).id, direction: "long", quantity: 1, quoted_price: @portfolio.share_price(drivers(:verstappen)) },
        { driver_id: drivers(:leclerc).id, direction: "long", quantity: 1, quoted_price: 1 }
      ] }
    end
    assert_redirected_to market_fantasy_stock_portfolio_path(@portfolio)
    assert_match /price changed/, flash[:alert]
    assert_nil flash[:stock_cart_cleared]
    assert_equal before_cash, wallet.reload.cash
    assert_equal before_quantity, fantasy_stock_holdings(:codex_ver_long).reload.quantity
  end

  test "successful draft clears browser draft and reserves only short margin" do
    sign_in @user
    races(:melbourne_2026).update!(date: 2.days.from_now.to_date)
    price = @portfolio.share_price(drivers(:leclerc))
    cash = @portfolio.wallet.cash
    post buy_batch_fantasy_stock_portfolio_path(@portfolio), params: { orders: [
      { driver_id: drivers(:leclerc).id, direction: "short", quantity: 2, quoted_price: price }
    ] }
    assert_redirected_to fantasy_overview_path(@user.username)
    assert_equal @portfolio.id, flash[:stock_cart_cleared]
    assert_equal cash, @portfolio.wallet.reload.cash
    assert_in_delta price, @portfolio.active_shorts.find_by!(driver: drivers(:leclerc)).collateral
  end

  test "closed window and invalid draft never execute or clear draft" do
    sign_in @user
    [[{ driver_id: drivers(:leclerc).id, direction: "long", quantity: 1 }], [], "invalid", { driver_id: 1 }].each do |orders|
      assert_no_difference "FantasyStockTransaction.count" do
        post buy_batch_fantasy_stock_portfolio_path(@portfolio), params: { orders: orders }
      end
      assert_redirected_to market_fantasy_stock_portfolio_path(@portfolio)
      assert_nil flash[:stock_cart_cleared]
    end
  end

  # /stocks/leaderboard was linked from nowhere and ranked on stock-only value,
  # so it published different figures from /leaderboard for the same player.
  # Folded into the canonical standings page.
  test "legacy stock leaderboard redirects to the combined leaderboard" do
    sign_in @user
    get "/stocks/leaderboard"
    assert_redirected_to combined_leaderboard_path
  end
end
