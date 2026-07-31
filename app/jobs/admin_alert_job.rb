class AdminAlertJob < ApplicationJob
  queue_as :default

  def perform(title:, message:, source:, severity: "info")
    AdminAlert.create!(title: title, message: message, source: source, severity: severity)
  end
end
