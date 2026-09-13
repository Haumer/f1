namespace :f1 do
  desc 'Dry-run a latest-race repair from an explicit official URL. RACE_ID= SOURCE_URL= [APPLY=1 CONFIRM_RACE= BACKUP_ID=]'
  task repair_latest_race: :environment do
    race = Race.find(Integer(ENV.fetch('RACE_ID')))
    apply = ENV['APPLY'] == '1'
    abort 'Applying requires CONFIRM_RACE to exactly match RACE_ID and a verified BACKUP_ID' if apply &&
      (ENV['CONFIRM_RACE'] != race.id.to_s || ENV['BACKUP_ID'].blank?)
    rows = RaceResults::OfficialClassification.new(race: race, url: ENV.fetch('SOURCE_URL')).call
    result = RaceResults::RepairLatest.new(race: race, rows: rows, dry_run: !apply, backup_id: ENV['BACKUP_ID']).call
    puts JSON.pretty_generate(result)
  end
end
