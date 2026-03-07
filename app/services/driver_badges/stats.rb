module DriverBadges::Stats
  private

  def total_races
    @sorted_results.size
  end

  def total_wins
    @sorted_results.count { |rr| rr.position_order == 1 }
  end

  def total_podiums
    @sorted_results.count { |rr| rr.position_order && rr.position_order <= 3 }
  end

  def total_second_places
    @sorted_results.count { |rr| rr.position_order == 2 }
  end

  def total_fourth_places
    @sorted_results.count { |rr| rr.position_order == 4 }
  end

  def total_finished
    @sorted_results.count { |rr| rr.status&.finished? || rr.status&.lapped? }
  end

  def total_crashes
    @sorted_results.count { |rr| rr.status&.accident? || rr.status&.retired? || rr.status&.health? }
  end

  def total_mechanical
    @sorted_results.count { |rr| rr.status&.technical? }
  end

  def total_outside_top_ten
    @sorted_results.count { |rr| rr.position_order && rr.position_order > 10 }
  end

  def total_lapped
    @sorted_results.count { |rr| rr.status&.lapped? }
  end

  def longest_streak(results)
    max = 0
    current = 0
    results.each do |rr|
      if yield(rr)
        current += 1
        max = current if current > max
      else
        current = 0
      end
    end
    max
  end
end
