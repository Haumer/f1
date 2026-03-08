require "test_helper"

class PredictionsHelperTest < ActionView::TestCase
  test "linkify_reasoning returns empty string for blank" do
    assert_equal "", linkify_reasoning(nil)
    assert_equal "", linkify_reasoning("")
  end

  test "linkify_reasoning converts token to link" do
    result = linkify_reasoning("Won {here in 2024|/races/42} with Ferrari")
    assert_includes result, '<a class="pn-inline-link" href="/races/42">here in 2024</a>'
    assert_includes result, "Won"
    assert_includes result, "with Ferrari"
  end

  test "linkify_reasoning handles multiple tokens" do
    text = "{Driver A|/drivers/1} beat {Driver B|/drivers/2}"
    result = linkify_reasoning(text)
    assert_includes result, 'href="/drivers/1"'
    assert_includes result, 'href="/drivers/2"'
  end

  test "linkify_reasoning adds target blank for external links" do
    result = linkify_reasoning("{source|https://example.com}")
    assert_includes result, 'target="_blank"'
    assert_includes result, 'rel="noopener"'
  end

  test "linkify_reasoning leaves plain text unchanged" do
    text = "Just a regular sentence"
    assert_equal text, linkify_reasoning(text)
  end

  test "linkify_reasoning returns html_safe string" do
    result = linkify_reasoning("text {link|/path}")
    assert result.html_safe?
  end
end
