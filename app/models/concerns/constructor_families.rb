module ConstructorFamilies
  extend ActiveSupport::Concern

  # Maps constructor "families" — teams and their historical incarnations.
  # Key: family name, Value: array of constructor_refs that belong to that family.
  FAMILIES = {
    "Ferrari" => %w[ferrari],
    "McLaren" => %w[mclaren mclaren-ford mclaren-brm mclaren-alfa_romeo mclaren-seren],
    "Mercedes" => %w[mercedes],
    "Red Bull" => %w[red_bull],
    "Williams" => %w[williams],
    "Alpine / Renault" => %w[alpine renault],
    "Aston Martin / Force India / Racing Point" => %w[aston_martin force_india racing_point spyker spyker_mf1 jordan],
    "RB / AlphaTauri / Toro Rosso" => %w[rb alphatauri toro_rosso],
    "Alfa Romeo / Sauber" => %w[alfa sauber alfa-romeo bmw_sauber],
    "Haas" => %w[haas],
    "Lotus" => %w[team_lotus lotus_f1 lotus_racing lotus-climax lotus-ford lotus-brm lotus-borgward lotus-maserati lotus-pw],
    "Brabham" => %w[brabham brabham-repco brabham-climax brabham-ford brabham-brm brabham-alfa_romeo],
    "Tyrrell" => %w[tyrrell],
    "BRM" => %w[brm brm-ford],
    "Cooper" => %w[cooper cooper-climax cooper-maserati cooper-borgward cooper-ferrari cooper-brm cooper-ats cooper-alfa_romeo cooper-castellotti cooper-ford cooper-osca],
    "Maserati" => %w[maserati],
    "Benetton" => %w[benetton],
    "Brawn" => %w[brawn],
    "Ligier" => %w[ligier],
    "March" => %w[march march-ford march-alfa_romeo],
    "Shadow" => %w[shadow shadow-ford shadow-matra],
    "Matra" => %w[matra matra-ford],
    "Eagle" => %w[eagle eagle-climax eagle-weslake],
    "Lancia" => %w[lancia],
    "Vanwall" => %w[vanwall],
    "BAR / Honda / Brawn / Mercedes" => nil, # Special: handled separately
    "Toyota" => %w[toyota],
    "Prost" => %w[prost],
    "Stewart / Jaguar / Red Bull" => nil, # Special: handled separately
  }.freeze

  # Full lineage chains (team → successor)
  LINEAGES = {
    "Red Bull Racing" => {
      chain: %w[stewart jaguar red_bull],
      labels: ["Stewart GP (1997-1999)", "Jaguar Racing (2000-2004)", "Red Bull Racing (2005-present)"]
    },
    "Mercedes" => {
      chain: %w[bar honda brawn mercedes],
      labels: ["BAR (1999-2005)", "Honda Racing (2006-2008)", "Brawn GP (2009)", "Mercedes (2010-present)"]
    },
    "Aston Martin" => {
      chain: %w[jordan mf1 spyker_mf1 spyker force_india racing_point aston_martin],
      labels: ["Jordan (1991-2005)", "MF1 Racing (2006)", "Spyker MF1 (2006)", "Spyker F1 (2007)", "Force India (2008-2018)", "Racing Point (2019-2020)", "Aston Martin (2021-present)"]
    },
    "RB F1 Team" => {
      chain: %w[minardi toro_rosso alphatauri rb],
      labels: ["Minardi (1985-2005)", "Toro Rosso (2006-2019)", "AlphaTauri (2020-2023)", "RB F1 Team (2024-present)"]
    },
    "Alpine" => {
      chain: %w[toleman benetton renault lotus_f1 renault alpine],
      labels: ["Toleman (1981-1985)", "Benetton (1986-2001)", "Renault (2002-2011)", "Lotus F1 (2012-2015)", "Renault (2016-2020)", "Alpine (2021-present)"]
    },
    "Alfa Romeo / Sauber" => {
      chain: %w[sauber bmw_sauber sauber alfa sauber],
      labels: ["Sauber (1993-2005)", "BMW Sauber (2006-2009)", "Sauber (2010-2018)", "Alfa Romeo (2019-2023)", "Sauber / Audi (2024-present)"]
    },
  }.freeze

  class_methods do
    def family_for(constructor)
      ref = constructor.constructor_ref
      FAMILIES.each do |family_name, refs|
        next unless refs
        return family_name if refs.include?(ref)
      end
      constructor.name
    end

    def family_members(family_name)
      refs = FAMILIES[family_name]
      return Constructor.none unless refs
      Constructor.where(constructor_ref: refs)
    end

    def all_families_with_constructors
      FAMILIES.filter_map do |family_name, refs|
        next unless refs
        constructors = Constructor.where(constructor_ref: refs).order(:name)
        next if constructors.empty?
        [family_name, constructors]
      end
    end

    def lineages
      LINEAGES
    end
  end
end
