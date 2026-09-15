require 'net/smtp'
require 'openssl'

module TransactionalEmail
  DELIVERY_ERRORS = [Net::SMTPError, IOError, SystemCallError, SocketError,
                     Timeout::Error, OpenSSL::SSL::SSLError].freeze

  module_function

  def configured?(env = ENV)
    !env['RESEND_API_KEY'].to_s.strip.empty?
  end

  def sender(env = ENV)
    value = env['MAILER_FROM'].to_s.strip
    value.empty? ? 'F1 Elo <noreply@f1elo.com>' : value
  end

  def smtp_settings(env = ENV)
    {
      address: 'smtp.resend.com', port: 587, domain: 'f1elo.com',
      user_name: 'resend', password: env['RESEND_API_KEY'].to_s.strip,
      authentication: :plain, enable_starttls: true, enable_starttls_auto: false,
      openssl_verify_mode: OpenSSL::SSL::VERIFY_PEER,
      open_timeout: 5, read_timeout: 10
    }
  end
end
