require "test_helper"

class PublicManifestTest < ActiveSupport::TestCase
  setup do
    @manifest = JSON.parse(Rails.root.join("public/manifest.webmanifest").read)
  end

  test "manifest has an installable app identity and valid icon purposes" do
    assert_equal "/", @manifest.fetch("id")
    assert_equal "/", @manifest.fetch("start_url")
    assert_equal "/", @manifest.fetch("scope")

    valid_purposes = %w[any maskable monochrome]
    @manifest.fetch("icons").each do |icon|
      icon.fetch("purpose", "any").split.each do |purpose|
        assert_includes valid_purposes, purpose
      end
    end
  end
end
