require 'test_helper'
require 'minitest/mock'

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    Rack::Attack.reset!
    @user = users(:codex)
    @original_url_options = ActionMailer::Base.default_url_options
    ActionMailer::Base.default_url_options = { host: 'f1elo.com', protocol: 'https' }
  end

  teardown do
    Rack::Attack.reset!
    ActionMailer::Base.default_url_options = @original_url_options
  end

  test 'reset email has the real sender and a working one-use HTTPS reset link' do
    assert_emails 1 do
      post user_password_path, params: { user: { email: @user.email } }
    end
    assert_response :redirect
    mail = ActionMailer::Base.deliveries.last
    assert_equal ['noreply@f1elo.com'], mail.from
    assert_equal [@user.email], mail.to
    body = mail.html_part&.decoded || mail.body.decoded
    reset_url = Nokogiri::HTML(body).at_css('a')['href']
    assert reset_url.start_with?('https://f1elo.com/users/password/edit?')
    raw_token = Rack::Utils.parse_query(URI(reset_url).query).fetch('reset_password_token')
    refute_equal raw_token, @user.reload.reset_password_token

    put user_password_path, params: { user: { reset_password_token: raw_token,
      password: 'new-test-password-456', password_confirmation: 'new-test-password-456' } }
    assert_response :redirect
    assert @user.reload.valid_password?('new-test-password-456')
    assert_nil @user.reset_password_token
    refute User.reset_password_by_token(reset_password_token: raw_token,
      password: 'another-test-password', password_confirmation: 'another-test-password').persisted?
  end

  test 'missing production configuration does not rotate a token or reveal account existence' do
    @user.update_columns(reset_password_token: 'existing-test-token', reset_password_sent_at: Time.current)
    original_token = @user.reset_password_token
    Rails.env.stub(:production?, true) do
      TransactionalEmail.stub(:configured?, false) do
        [@user.email, 'absent@example.com'].each do |email|
          assert_no_emails { post user_password_path, params: { user: { email: email } }, headers: { 'HOST' => 'f1elo.com' } }
          assert_response :service_unavailable
          assert_includes response.body, 'Password reset emails are temporarily unavailable'
          assert_equal '60', response.headers['Retry-After']
        end
      end
    end
    assert_equal original_token, @user.reload.reset_password_token
  end

  test 'SMTP failure renders an honest retryable error instead of crashing' do
    failure = ->(*) { raise Errno::ECONNREFUSED, 'test-only delivery failure' }
    User.stub(:send_reset_password_instructions, failure) do
      assert_no_emails { post user_password_path, params: { user: { email: @user.email } } }
    end
    assert_response :service_unavailable
    assert_includes response.body, 'Password reset emails are temporarily unavailable'
    refute_includes response.body, 'test-only delivery failure'
  end

  test 'unexpected application errors are not disguised as mail failures' do
    failure = ->(*) { raise ArgumentError, 'unexpected application bug' }
    User.stub(:send_reset_password_instructions, failure) do
      post user_password_path, params: { user: { email: @user.email } }
    end
    assert_response :internal_server_error
    assert_nil flash[:alert]
  end
end
