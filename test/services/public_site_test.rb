require "test_helper"

class PublicSiteTest < ActiveSupport::TestCase
  test "defaults to the production HTTPS origin" do
    assert_equal "https://f1elo.com", PublicSite.base_url(host: PublicSite::DEFAULT_HOST)
    assert_equal "https://f1elo.com/elo", PublicSite.url("/elo", host: PublicSite::DEFAULT_HOST)
    assert_equal "f1elo.com", PublicSite.host(configured_host: PublicSite::DEFAULT_HOST)
  end

  test "normalizes hosts and paths" do
    assert_equal "https://preview.example/elo", PublicSite.url("elo", host: "preview.example/")
    assert_equal "http://localhost:3000/", PublicSite.url("/", host: "http://localhost:3000/")
    assert_equal "https://f1elo.com/", PublicSite.url("/", host: "  ")
  end
end
