module Users
  class PasswordsController < Devise::PasswordsController
    def create
      # Check before looking up an account or replacing its reset token. An
      # unconfigured provider must never pretend an email has been sent.
      return delivery_unavailable if Rails.env.production? && !TransactionalEmail.configured?

      super
    rescue *TransactionalEmail::DELIVERY_ERRORS => error
      # SMTP responses can contain addresses or other sensitive details. Keep
      # the error visible to operators without copying the response into logs.
      Rails.logger.error("[Password reset] Email delivery failed: #{error.class.name}")
      Sentry.capture_message('Password reset email delivery failed', level: :error,
                             extra: { error_class: error.class.name }) if defined?(Sentry)
      delivery_unavailable
    end

    private

    def delivery_unavailable
      self.resource = resource_class.new(email: resource_params[:email])
      flash.now[:alert] = 'Password reset emails are temporarily unavailable. Please try again later.'
      response.set_header('Retry-After', '60')
      render :new, status: :service_unavailable
    end
  end
end
