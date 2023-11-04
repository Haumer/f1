module ApplicationHelper

    def finished?(status_type)
        status_type.downcase == "finished" || status_type.downcase.include?("lap")
    end
end
