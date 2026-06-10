# Era buckets used by /stats champion timeline and /races winners. Kept in
# one place so adding a new era (or shifting boundaries when "Hybrid" stops
# fitting) is a single edit.
module Championship
  ERAS = {
    "Pioneers"      => 1950..1969,
    "Ground Effect" => 1970..1989,
    "Modern"        => 1990..2009,
    "Hybrid"        => 2010..2099
  }.freeze
end
