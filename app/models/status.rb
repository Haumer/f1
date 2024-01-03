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
        status_type.in?(LAPPED_REASONS)
    end
    
    def accident?
        status_type.in?(ACCIDENT_REASONS)
    end

    TECHNICAL_REASONS = [
        "Engine",
        "Gearbox",
        "Transmission",
        "Clutch",
        "Hydraulics",
        "Electrical",
        "Radiator",
        "Suspension",
        "Brakes",
        "Differential",
        "Overheating",
        "Mechanical",
        "Tyre",
        "Driver Seat",
        "Puncture",
        "Driveshaft",
        "Fuel pressure",
        "Front wing",
        "Water pressure",
        "Wheel",
        "Throttle",
        "Steering",
        "Technical",
        "Electronics",
        "Broken wing",
        "Heat shield fire",
        "Exhaust",
        "Oil leak",
        "Wheel rim",
        "Water leak",
        "Fuel pump",
        "Track rod",
        "Engine fire",
        "Engine misfire",
        "Tyre puncture",
        "Wheel nut",
        "Pneumatics",
        "Handling",
        "Rear wing",
        "Fire",
        "Wheel bearing",
        "Physical",
        "Fuel system",
        "Oil line",
        "Fuel rig",
        "Launch control",
        "Power loss",
        "Vibrations",
        "Ignition",
        "Halfshaft",
        "Crankshaft",
        "Chassis",
        "Battery",
        "Alternator",
        "Oil pump",
        "Fuel leak",
        "Injection",
        "Distributor",
        "Turbo",
        "CV joint",
        "Water pump",
        "Spark plugs",
        "Fuel pipe",
        "Oil pipe",
        "Axle",
        "Water pipe",
        "Supercharger",
        "Collision damage",
        "Power Unit",
        "Seat",
        "Damage",
        "Debris",
        "Undertray",
        "Cooling system",
        "Safety belt",
        "Oil pressure",
        "Brake duct",
    ]

    DRIVER_HEALTH_REASONS = [
        "Injured",
        "Driver unwell",
        "Fatal accident",
        "Eye injury",
        "Illness",
    ]

    ACCIDENT_REASONS = [
        "Accident",
        "Collision",
    ]

    LAPPED_REASONS = [
        "+1 Lap",
        "+2 Laps",
        "+3 Laps",
        "+4 Laps",
        "+5 Laps",
        "+6 Laps",
        "+7 Laps",
        "+8 Laps",
        "+9 Laps",
        "+14 Laps",
        "+15 Laps",
        "+25 Laps",
        "+18 Laps",
        "+22 Laps",
        "+16 Laps",
        "+24 Laps",
        "+29 Laps",
        "+23 Laps",
        "+21 Laps",
        "+44 Laps",
        "+30 Laps",
        "+19 Laps",
        "+46 Laps",
        "+20 Laps",
        "+49 Laps",
        "+38 Laps",
        "+11 Laps",
        "+17 Laps",
        "+42 Laps",
        "+13 Laps",
        "+12 Laps",
        "+26 Laps",
        "+10 Laps",
    ]
    OTHER_REASONS = [
        "ERS",
        "Spun off",
        "Retired",
        "Refuelling",
        "Withdrew",
        "Out of fuel",
        "Not classified",
        "Fuel",
        "107% Rule",
        "Safety",
        "Drivetrain",
        "Did not qualify",
        "Injury",
        "Stalled",
        "Safety concerns",
        "Not restarted",
        "Underweight",
        "Excluded",
        "Did not prequalify",
        "Magneto",
    ]
end
