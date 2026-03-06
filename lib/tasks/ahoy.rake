namespace :ahoy do
  desc "Remove Ahoy visits and events older than 90 days"
  task prune: :environment do
    cutoff = 90.days.ago
    events = Ahoy::Event.where("time < ?", cutoff).delete_all
    visits = Ahoy::Visit.where("started_at < ?", cutoff).delete_all
    puts "Pruned #{events} events and #{visits} visits older than #{cutoff.to_date}"
  end
end
