require 'test_helper'

class TransactionalEmailTest < ActiveSupport::TestCase
  test 'missing or blank keys are not configured' do
    refute TransactionalEmail.configured?({})
    refute TransactionalEmail.configured?('RESEND_API_KEY' => '  ')
    assert TransactionalEmail.configured?('RESEND_API_KEY' => 'test-only-key')
  end

  test 'SMTP uses Resend with required TLS certificate verification and timeouts' do
    settings = TransactionalEmail.smtp_settings('RESEND_API_KEY' => ' test-only-key ')
    assert_equal 'smtp.resend.com', settings[:address]
    assert_equal 587, settings[:port]
    assert_equal 'resend', settings[:user_name]
    assert_equal 'test-only-key', settings[:password]
    assert settings[:enable_starttls]
    refute settings[:enable_starttls_auto]
    assert_equal OpenSSL::SSL::VERIFY_PEER, settings[:openssl_verify_mode]
    assert_equal 5, settings[:open_timeout]
    assert_equal 10, settings[:read_timeout]
  end

  test 'sender defaults to the app domain and supports a verified override' do
    assert_equal 'F1 Elo <noreply@f1elo.com>', TransactionalEmail.sender({})
    assert_equal 'F1 Elo <noreply@f1elo.com>', TransactionalEmail.sender('MAILER_FROM' => ' ')
    assert_equal 'Accounts <accounts@mail.f1elo.com>', TransactionalEmail.sender('MAILER_FROM' => 'Accounts <accounts@mail.f1elo.com>')
    assert_equal TransactionalEmail.sender, Devise.mailer_sender
    assert_equal TransactionalEmail.sender, ApplicationMailer.default[:from]
  end
end
