# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, "https://fonts.gstatic.com"
    policy.img_src     :self, :data, "https://flagsapi.com", "https://*.wikipedia.org", "https://upload.wikimedia.org"
    policy.object_src  :none
    policy.script_src  :self, :unsafe_inline, "https://www.googletagmanager.com", "https://ga.jspm.io", "https://cdn.jsdelivr.net"
    policy.style_src   :self, :unsafe_inline, "https://fonts.googleapis.com"
    policy.connect_src :self, "https://www.google-analytics.com", "https://www.googletagmanager.com"
    policy.frame_src   "https://www.youtube.com", "https://www.youtube-nocookie.com"
  end

  # Report violations without enforcing the policy.
  config.content_security_policy_report_only = true
end
