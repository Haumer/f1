module Admin
  class AlertsController < BaseController
    def update
      alert = AdminAlert.find(params[:id])
      alert.resolve!
      redirect_back fallback_location: admin_root_path, notice: "Alert resolved."
    end
  end
end
