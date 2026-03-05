module Alertable
  extend ActiveSupport::Concern

  included do
    rescue_from(StandardError) do |exception|
      AdminAlert.create!(
        title: "#{self.class.name} failed",
        message: "#{exception.class}: #{exception.message}\n#{exception.backtrace&.first(5)&.join("\n")}",
        severity: "error",
        source: self.class.name
      )
      raise exception
    end
  end
end
