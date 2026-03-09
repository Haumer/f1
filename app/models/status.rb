class Status < ApplicationRecord

    def finished?
        status_type == "Finished"
    end

    def disqualified?
        status_type == "Disqualified"
    end

    def technical?
        status_type.in?(TECHNICAL_REASONS)
    end

    def lapped?
        status_type == "Lapped" || status_type.match?(/\A\+\d+ Laps?\z/)
    end

    def accident?
        status_type.in?(ACCIDENT_REASONS)
    end

    def retired?
        status_type.in?(RETIRED_REASONS)
    end

    def health?
        status_type.in?(DRIVER_HEALTH_REASONS)
    end

    def did_not_start?
        status_type.in?(DID_NOT_START_REASONS)
    end

    TECHNICAL_REASONS = %w[
        Engine Gearbox Transmission Clutch Hydraulics Electrical Radiator
        Suspension Brakes Differential Overheating Mechanical Tyre Puncture
        Driveshaft Throttle Steering Technical Electronics Exhaust Pneumatics
        Handling Fire Physical Ignition Halfshaft Crankshaft Chassis Battery
        Alternator Turbo Axle Supercharger Damage Debris Undertray ERS
        Drivetrain Magneto Stalled Injection Distributor Vibrations Seat
    ].freeze + [
        "Driver Seat", "Fuel pressure", "Front wing", "Water pressure",
        "Wheel", "Broken wing", "Heat shield fire", "Oil leak", "Wheel rim",
        "Water leak", "Fuel pump", "Track rod", "Engine fire", "Engine misfire",
        "Tyre puncture", "Wheel nut", "Rear wing", "Wheel bearing",
        "Fuel system", "Oil line", "Fuel rig", "Launch control", "Power loss",
        "Oil pump", "Fuel leak", "CV joint", "Water pump", "Spark plugs",
        "Fuel pipe", "Oil pipe", "Water pipe", "Collision damage", "Power Unit",
        "Cooling system", "Safety belt", "Oil pressure", "Brake duct",
        "Out of fuel", "Refuelling",
    ].freeze

    DRIVER_HEALTH_REASONS = [
        "Injured", "Driver unwell", "Eye injury", "Illness", "Injury",
    ].freeze

    RETIRED_REASONS = [
        "Retired", "Withdrew", "Not classified", "Not restarted",
        "Safety", "Safety concerns",
    ].freeze

    DID_NOT_START_REASONS = [
        "Did not qualify", "Did not prequalify", "Did not start",
        "107% Rule", "Excluded", "Underweight",
    ].freeze

    ACCIDENT_REASONS = [
        "Accident", "Collision", "Spun off", "Fatal accident",
    ].freeze
end
