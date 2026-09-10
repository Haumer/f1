require "test_helper"

class SitemapsControllerTest < ActionDispatch::IntegrationTest
  test "sitemap exposes canonical public pages as valid XML" do
    get sitemap_path

    assert_response :success
    assert_includes response.media_type, "xml"

    document = Nokogiri::XML(response.body)
    assert_empty document.errors

    locations = document.xpath("//xmlns:url/xmlns:loc").map(&:text)
    assert_includes locations, PublicSite.url("/")
    assert_includes locations, PublicSite.url("/elo")
    assert locations.any? { |location| location.start_with?(PublicSite.url("/drivers/")) }
    assert_equal locations.uniq, locations
    refute locations.any? { |location| location.include?("/admin") || location.include?("/users/") }
  end
end
