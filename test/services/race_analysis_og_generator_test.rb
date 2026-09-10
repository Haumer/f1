require "test_helper"
require "minitest/mock"

class RaceAnalysisOgGeneratorTest < ActiveSupport::TestCase
  test "image generation uses argv and strips draw-language controls and expressions" do
    payload = { circuit: "Bob's \\" + "Circuit\n%[fx:1]", year: 2026, round: 1, assessed: 1, entrants: 20,
                top: [{ name: "O'Name\n%[test]", expected: 10.5, finish: 6, difference: 4.5 }], flop: [] }
    generator = RaceAnalysisOgGenerator.new(payload)
    capture = lambda do |*args, **options|
      assert_equal "magick", args.first
      assert_includes args, "1200x630"
      assert_equal "png:-", args.last
      assert_equal true, options[:binmode]
      assert_includes args, "text 96,257 'OName[test]'"
      assert_not args.any? { |arg| arg.include?("%[") || arg.include?("\n") }
      ["PNG bytes", "", Struct.new(:success?).new(true)]
    end
    generator.stub(:magick_bin, "magick") do
      Open3.stub(:capture3, capture) { assert_equal "PNG bytes", generator.generate }
    end
  end

  test "renderer errors do not return or cache corrupt image bytes" do
    payload = { circuit: "Test", year: 2026, round: 1, assessed: 0, entrants: 20, top: [], flop: [] }
    generator = RaceAnalysisOgGenerator.new(payload)
    generator.stub(:magick_bin, "magick") do
      Open3.stub(:capture3, ["", "renderer failed", Struct.new(:success?).new(false)]) do
        assert_raises(RuntimeError) { generator.generate }
      end
    end
  end
end
