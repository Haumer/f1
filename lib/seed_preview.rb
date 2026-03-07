race = Race.find(1126)

content = <<~MD
## Circuit Character

Albert Park is a semi-permanent street circuit that demands a well-balanced car. The mix of high-speed sweeps (turns 1-2, turn 11-12), heavy braking zones (turn 3, turn 9, turn 13), and tight chicanes means you cannot sacrifice one area for another. The resurfaced and reconfigured layout (since 2022) has produced more overtaking opportunities, particularly into turn 3, turn 9, and the newly opened turn 11. It rewards drivers who can extract confidence under braking and carry speed through fast direction changes.

Historically, this has been a track where **the top teams dominate** but the order among them shifts. Ferrari won here in 2024, McLaren in 2025, Red Bull/Mercedes in prior years. No single constructor has owned this circuit in the modern era, making it a genuine litmus test of the pecking order.

## Form Guide

**Max Verstappen (Elo: 2553)** enters the season as the clear Elo leader, 113 points clear of second-placed George Russell. But his 2025 campaign saw a significant Elo decline from a peak of 2692 -- a drop of 139 points that suggests Red Bull's relative performance has eroded. Still, P2 here last year proves he remains dangerous at Albert Park.

**Lando Norris (Elo: 2431)** is the defending winner at this circuit. McLaren's 2025 constructors' campaign was historically strong, and Norris's Elo peak of 2534 came during that run. The question is whether McLaren's momentum carries into the new regulations cycle.

**Oscar Piastri (Elo: 2409)** is the local hero -- the Melbourne crowd will be fully behind the Aussie. His peak Elo of 2556 was actually *higher* than Norris's current rating, indicating he hit staggering form in 2025. A home podium is very much on the cards.

**Lewis Hamilton (Elo: 2210)** starts his second season at Ferrari with something to prove. His Elo has dropped dramatically from a career peak of 2661 -- the largest active decline of any top driver. But Albert Park has been kind to him historically (P2 in 2023), and the new Ferrari-Hamilton partnership has had a full winter to gel.

**George Russell (Elo: 2440)** quietly sits as the second-highest-rated driver. His consistency has been remarkable, with his Elo never far from his peak of 2452. With Kimi Antonelli (Elo: 2214) as his new teammate, Russell has a chance to assert himself as a clear team leader.

## Key Battles

**McLaren vs Red Bull vs Ferrari** -- The constructor Elo tells a fascinating story: Red Bull (1552) still leads, but Ferrari (1408) and Mercedes (1404) are virtually tied, with McLaren (1357) not far behind. This is the tightest four-way fight the Elo system has captured since 2012. Any of these teams could win on Sunday.

**The Antonelli debut** -- Kimi Antonelli (Elo: 2214) steps into the seat vacated by Hamilton. At just 19, replacing a seven-time champion at Mercedes is immense pressure. Albert Park's unforgiving walls will test his composure. His Elo is respectable for a rookie but 226 points below Russell's -- the gap Mercedes will want to see shrink quickly.

**Sainz at Williams** -- Carlos Sainz (Elo: 2128) won this very race in 2024 with Ferrari. Now at Williams (constructor Elo: 843 -- lowest of the established teams), he faces a stark reality check. Can he drag that car into the points? His personal Elo drop from a peak of 2365 reflects both the car change and the challenge ahead.

**The new entries** -- Audi and Cadillac F1 Team enter with no Elo history at all. Both will be at the back, but their development trajectories will be worth watching over the season.

## Prediction

1. **Lando Norris** -- Defending winner, McLaren likely still strong out of the box, and his Elo trajectory has been consistently upward. Track knowledge from last year's win is invaluable.
2. **Max Verstappen** -- Too talented to bet against, even if Red Bull's relative pace has slipped. His Elo gap to the field is still enormous. Expect him to be in the fight.
3. **Oscar Piastri** -- Home race energy, elite Elo form from 2025 (peak 2556), and a car that should be competitive. A podium at Albert Park would be a statement.
4. **George Russell** -- Consistent, high-Elo performer who always seems to extract the maximum. Mercedes at 1404 constructor Elo means the car should be in the ballpark.
5. **Charles Leclerc** -- Ferrari's constructor Elo (1408) suggests a competitive package, and Leclerc's talent at circuits with hard braking zones is well-documented. P2 here in 2024 shows he knows the place.
MD

picks = {
  "winner" => "Lando Norris",
  "podium" => ["Lando Norris", "Max Verstappen", "Oscar Piastri"],
  "top5" => ["Lando Norris", "Max Verstappen", "Oscar Piastri", "George Russell", "Charles Leclerc"],
  "fastest_lap" => "Max Verstappen",
  "dark_horse" => "Lewis Hamilton",
  "dnf_risk" => "Andrea Kimi Antonelli"
}

sources = [
  { "title" => "F1 Elo Driver Ratings", "url" => "https://f1elo.com/drivers/grid", "type" => "data" },
  { "title" => "Albert Park Circuit History", "url" => "https://f1elo.com/circuits/1", "type" => "data" },
  { "title" => "Constructor Elo Rankings", "url" => "https://f1elo.com/constructors/elo_rankings", "type" => "data" },
  { "title" => "2025 Australian GP Results", "url" => "https://f1elo.com/races/1102", "type" => "data" },
  { "title" => "Hamilton adjusting to Ferrari in pre-season testing", "type" => "news" },
  { "title" => "Antonelli confirmed as Mercedes second driver for 2026", "type" => "news" },
  { "title" => "Cadillac and Audi enter as new constructors for 2026", "type" => "news" }
]

analysis = race.ai_analyses.find_or_initialize_by(analysis_type: "race_preview")
analysis.update!(
  content: content,
  picks: picks,
  sources: sources,
  generated_at: Time.current
)
puts "Saved analysis ID: #{analysis.id}"
