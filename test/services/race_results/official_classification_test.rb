require 'test_helper'
require 'minitest/mock'

class RaceResults::OfficialClassificationTest < ActiveSupport::TestCase
  setup do
    @race = races(:bahrain_2026)
    @url = 'https://www.formula1.com/en/results/2026/races/1234/bahrain/race-result'
    @source = RaceResults::OfficialClassification.new(race: @race, url: @url)
    @drivers = @race.race_results.includes(:driver).order(:position_order).map(&:driver)
    Status.find_or_create_by!(status_type: 'Retired')
  end

  test 'reads complete official results and grid without changing records' do
    before = @race.race_results.order(:id).map(&:attributes)
    rows = with_documents { @source.call }
    assert_equal 4, rows.size
    assert_equal @drivers.map(&:id), rows.map { |row| row[:driver_id] }
    assert_equal 2, rows.first[:grid]
    assert_equal 'Retired', Status.find(rows.last[:status_id]).status_type
    assert_equal before, @race.race_results.order(:id).map(&:attributes)
  end

  test 'a provider code difference still requires an exact surname in the event field' do
    @drivers.first.update!(code: 'OLD')
    rows = with_documents { @source.call }
    assert_equal @drivers.first.id, rows.first[:driver_id]
  end

  test 'wrong date or circuit fails closed' do
    [document(:results).to_html.sub(@race.date.strftime('%d %b %Y'), '01 Jan 2020'),
     document(:results).to_html.sub(@race.circuit.name, 'Monza')].each do |html|
      @source.stub(:fetch, Nokogiri::HTML(html)) do
        assert_raises(RaceResults::ImportGuard::Rejected) { @source.call }
      end
    end
  end

  test 'missing grid drivers are rejected' do
    incomplete = document(:grid)
    incomplete.css('tbody tr').last.remove
    @source.stub(:fetch, ->(uri) { uri.path.end_with?('/starting-grid') ? incomplete : document(:results) }) do
      assert_raises(RaceResults::ImportGuard::Rejected) { @source.call }
    end
  end

  test 'an extra duplicate grid entry is rejected even when all drivers are present' do
    duplicate = document(:grid)
    duplicate.at_css('tbody').add_child(duplicate.at_css('tbody tr').dup)
    @source.stub(:fetch, ->(uri) { uri.path.end_with?('/starting-grid') ? duplicate : document(:results) }) do
      assert_raises(RaceResults::ImportGuard::Rejected) { @source.call }
    end
  end

  test 'only explicit official result URLs may be fetched' do
    source = RaceResults::OfficialClassification.new(race: @race, url: 'https://example.com/race-result')
    source.stub(:fetch, ->(*) { flunk 'Must reject URL before fetching' }) do
      assert_raises(RaceResults::ImportGuard::Rejected) { source.call }
    end
  end

  private

  def with_documents(&block)
    @source.stub(:fetch, ->(uri) { document(uri.path.end_with?('/starting-grid') ? :grid : :results) }, &block)
  end

  def document(kind)
    headers = kind == :grid ? ['Pos.', 'No.', 'Driver', 'Team', 'Time'] :
      ['Pos.', 'No.', 'Driver', 'Team', 'Laps', 'Time / Retired', 'Pts.']
    codes = %w[VER NOR LEC PIA]
    rows = @drivers.each_with_index.map do |driver, i|
      name = "<span class='max-md:hidden'>#{driver.surname}</span><span class='md:hidden'>#{codes[i]}</span>"
      cells = if kind == :grid
        [i == 0 ? 2 : (i == 1 ? 1 : i + 1), i + 1, name, 'McLaren', '1:30.000']
      else
        [i == 3 ? 'NC' : i + 1, i + 1, name, 'McLaren', i == 3 ? 40 : 57, i == 3 ? 'DNF' : '1:30:00.000', i == 0 ? 25 : 0]
      end
      "<tr>#{cells.map { |cell| "<td>#{cell}</td>" }.join}</tr>"
    end.join
    Nokogiri::HTML("<h1>#{@race.circuit.name}</h1><p>#{@race.date.strftime('%d %b %Y')}</p><table><thead><tr>#{headers.map { |h| "<th>#{h}</th>" }.join}</tr></thead><tbody>#{rows}</tbody></table>")
  end
end
