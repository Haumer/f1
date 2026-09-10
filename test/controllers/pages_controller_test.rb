require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "home returns 200" do
    get root_path
    assert_response :success
  end

  test "home publishes crawl and sharing metadata" do
    get root_path

    expected_url = PublicSite.url("/")
    assert_select "link[rel='canonical'][href=?]", expected_url
    assert_select "meta[property='og:url'][content=?]", expected_url
    assert_select "meta[property='og:image'][content=?]", PublicSite.url("/og-image.png")
    assert_select "meta[name='mobile-web-app-capable'][content='yes']"

    schema_element = css_select("script[type='application/ld+json']").sole
    schema = JSON.parse(schema_element.text)
    assert_equal "WebSite", schema["@type"]
    assert_equal "F1 Elo", schema["name"]
    assert_equal expected_url, schema["url"]
  end

  test "canonical metadata excludes tracking parameters" do
    get elo_path, params: { utm_source: "launch" }

    expected_url = PublicSite.url("/elo")
    assert_select "link[rel='canonical'][href=?]", expected_url
    assert_select "meta[property='og:url'][content=?]", expected_url
    assert_select "script[type='application/ld+json']", count: 0
  end

  test "production redirects alternate hosts to the canonical origin" do
    host! "www.f1elo.com"
    original_environment = Rails.env
    Rails.env = ActiveSupport::EnvironmentInquirer.new("production")

    get elo_path, params: { race_id: 123 }

    assert_response :moved_permanently
    assert_equal PublicSite.url("/elo?race_id=123"), response.location
  ensure
    Rails.env = original_environment
  end

  test "about returns 200" do
    get about_path
    assert_response :success
  end

  test "terms returns 200" do
    get terms_path
    assert_response :success
  end

  test "fantasy_guide returns 200" do
    get fantasy_guide_path
    assert_response :success
  end

  test "fantasy landing presents the game to signed-out visitors" do
    get fantasy_home_path

    assert_response :success
    assert_select "h1", text: /Back your read/i
    assert_select "a[href=?]", new_user_registration_path, minimum: 1
    assert_select "a[href=?]", edit_race_picks_path, minimum: 1
    assert_select "meta[property='og:image'][content=?]", PublicSite.url("/fantasy-og.png")
    assert_select ".fantasy-console-row", minimum: 1
  end

  test "legacy fantasy guide URL redirects to its readable URL" do
    get "/fantasy_guide"

    assert_redirected_to fantasy_guide_path
  end

  test "elo returns 200" do
    get elo_path
    assert_response :success
    assert_select "h4", text: "Constructor Elo"
    assert_includes response.body, ConstructorEloV2::SCORING_METHOD
  end
end
