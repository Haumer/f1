module Users
  class RegistrationsController < Devise::RegistrationsController
    # After a successful signup, auto-provision a fantasy portfolio for the
    # current season. Errors are swallowed — onboarding must never break signup.
    def create
      super do |resource|
        next unless resource.persisted?
        provision_fantasy_portfolio(resource)
      end
    end

    protected

    # Devise calls this for the post-signup redirect. Land the user on their
    # (now-funded) fantasy overview instead of root — that's the whole point
    # of auto-provisioning.
    def after_sign_up_path_for(resource)
      if session[:pending_picks].present? && session[:pending_picks_race_id].present?
        return super
      end
      fantasy_overview_path(resource.username)
    end

    private

    def provision_fantasy_portfolio(user)
      season = Season.sorted_by_year.first
      return unless season
      Fantasy::CreatePortfolio.new(user: user, season: season).call
    rescue => e
      Rails.logger.error("[Users::RegistrationsController] auto-portfolio failed for ##{user.id}: #{e.class}: #{e.message}")
    end
  end
end
