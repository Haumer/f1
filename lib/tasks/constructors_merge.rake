namespace :constructors do
  desc "Merge duplicate constructor records (same constructor_ref)"
  task merge: :environment do
    dupes = Constructor.group(:constructor_ref).having("count(*) > 1").pluck(:constructor_ref)

    if dupes.empty?
      puts "No duplicate constructors found."
      next
    end

    puts "Found #{dupes.size} duplicate constructor_refs: #{dupes.join(', ')}"
    puts

    ActiveRecord::Base.transaction do
      dupes.each do |ref|
        records = Constructor.where(constructor_ref: ref).order(:id).to_a

        # Keep the one with the most race results (historical record)
        keep, *others = records.sort_by { |c| -c.race_results.count }

        others.each do |dupe|
          rr_count = RaceResult.where(constructor_id: dupe.id).count
          sd_count = SeasonDriver.where(constructor_id: dupe.id).count
          cs_count = ConstructorStanding.where(constructor_id: dupe.id).count

          # Reassign all foreign keys
          RaceResult.where(constructor_id: dupe.id).update_all(constructor_id: keep.id)
          SeasonDriver.where(constructor_id: dupe.id).update_all(constructor_id: keep.id)
          ConstructorStanding.where(constructor_id: dupe.id).update_all(constructor_id: keep.id)

          # Copy useful attributes from dupe if keep is missing them
          keep.update!(logo_url: dupe.logo_url) if keep.logo_url.blank? && dupe.logo_url.present?
          keep.update!(active: true) if dupe.active? && !keep.active?

          # Delete the duplicate
          dupe.destroy!

          puts "  #{ref.ljust(20)} merged ID #{dupe.id} → #{keep.id} (#{rr_count} race_results, #{sd_count} season_drivers, #{cs_count} constructor_standings)"
        end
      end

      # Deduplicate season_drivers that now have identical (season, driver, constructor)
      duped_sds = SeasonDriver.group(:season_id, :driver_id, :constructor_id).having("count(*) > 1").count
      duped_sds.each do |(season_id, driver_id, constructor_id), count|
        records = SeasonDriver.where(season_id: season_id, driver_id: driver_id, constructor_id: constructor_id).order(:id)
        records.offset(1).destroy_all
      end
      puts "\n  Deduplicated #{duped_sds.size} season_driver records" if duped_sds.any?
    end

    puts "\nDone. Remaining duplicates: #{Constructor.group(:constructor_ref).having('count(*) > 1').count.size}"
    puts "Total constructors: #{Constructor.count}"
    puts "\nRun ConstructorElo.recalculate_all! to recompute unified Elo ratings."
  end
end
