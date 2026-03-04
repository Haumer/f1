module ApplicationHelper

    def elo_tier(peak_elo)
        return nil unless peak_elo

        if Setting.use_elo_v2?
            if peak_elo >= 2600 then { label: "Elite", css: "elite" }
            elsif peak_elo >= 2450 then { label: "World Class", css: "world-class" }
            elsif peak_elo >= 2300 then { label: "Strong", css: "strong" }
            elsif peak_elo >= 2100 then { label: "Average", css: "average" }
            else { label: "Developing", css: "developing" }
            end
        else
            if peak_elo >= 1500 then { label: "Elite", css: "elite" }
            elsif peak_elo >= 1400 then { label: "World Class", css: "world-class" }
            elsif peak_elo >= 1300 then { label: "Strong", css: "strong" }
            elsif peak_elo >= 1200 then { label: "Average", css: "average" }
            else { label: "Developing", css: "developing" }
            end
        end
    end

    def finished?(status_type)
        return false if status_type.blank?
        status_type.downcase == "finished" || status_type.downcase.include?("lap")
    end

    def race_data(races, options = {})
        number_of_drivers = options[:number_of_drivers].present? ? options[:number_of_drivers] : 10
        criteria = options[:by].present? ? options[:by] : :peak_elo
        sorted_drivers = races.map(&:drivers).flatten.uniq.sort_by { |driver| -driver[criteria] }.first(number_of_drivers)
        mapped_by_race = sorted_drivers.map do |driver|
            {
                data: races.map do |race|
                    if race.drivers.pluck(:id).include?(driver.id)
                        {
                            name: race.circuit.name,
                            value: RaceResult.find_by(driver: driver, race: race).position_order
                        }
                    else
                        {
                            name: race.circuit.name
                        }
                    end
                end,
                type: 'line',
                name: driver.surname,
                color: driver.color,
            }
        end
        {
            label: {
                show: false,
                position: "right"
            },
            xAxis: {
                type: 'category',
                data: races.map{|race| "#{race.circuit.circuit_ref} #{race.date.year}"}
            },
            yAxis: {
                inverse: true,
                type: 'value',
                min: 1,
            },
            series: mapped_by_race,
            legend: { show: true },
            toolbox: { show: true },
            tooltip: { trigger: "axis", position: [10, 10]},
            dataZoom: [
                {
                    id: 'dataZoomX',
                    type: 'slider',
                    xAxisIndex: [0],
                    filterMode: 'filter'
                }
            ],
        }
    end

    def drivers_chart_data
        drivers = Driver.active.by_peak_elo
        races = Race.sorted.where(date: Driver.active.by_first_race_date.first.first_race_date..Date.today)
        mapped_by_race = drivers.map do |driver|
            {
                data: races.map do |race|
                    if race.drivers.pluck(:id).include?(driver.id)
                        {
                            name: race.circuit.name,
                            value: RaceResult.find_by(driver: driver, race: race).new_elo.round
                        }
                    else
                        {
                            name: race.circuit.name
                        }
                    end
                end,
                type: 'line',
                name: driver.surname,
                color: driver.color,
            }
        end
        {
            label: {
                show: false,
                position: "right"
            },
            xAxis: {
                type: 'category',
                data: races.map{|race| "#{race.circuit.circuit_ref} #{race.date.year}"}
            },
            yAxis: {
                type: 'value',
                min: Setting.use_elo_v2? ? 1500 : 800,
            },
            series: mapped_by_race,
            legend: { show: true },
            toolbox: { show: true },
            tooltip: { 
                trigger: "axis",
                position: [10, 10],
            },
            dataZoom: [
                {
                    id: 'dataZoomX',
                    type: 'slider',
                    xAxisIndex: [0],
                    filterMode: 'filter'
                }
            ],
        }
    end
end
