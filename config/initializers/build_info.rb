# Resolve once at boot so requests don't shell out to git.
#
# Sources:
#   * version  — Heroku release tag ("v199"), populated only when the
#                `runtime-dyno-metadata` labs feature is enabled on the app.
#                Falls back to "dev" on local / unflipped environments.
#   * branch   — local git branch on dev; on Heroku the slug doesn't track the
#                source branch, so we default to "main" (the only branch
#                allowed to deploy via `git push heroku main`).
#   * sha      — Heroku's SOURCE_VERSION (auto-set during slug build) or the
#                local HEAD when developing.
module BuildInfo
  REPO_URL = "https://github.com/Haumer/f1".freeze

  SHA = (
    ENV["SOURCE_VERSION"].presence ||
    (begin
      `git rev-parse HEAD 2>/dev/null`.strip.presence
    rescue StandardError
      nil
    end)
  ).freeze

  SHORT_SHA = SHA && SHA[0, 7]

  VERSION = (ENV["HEROKU_RELEASE_VERSION"].presence || "dev").freeze

  BRANCH = (
    ENV["GIT_BRANCH"].presence ||
    (begin
      `git rev-parse --abbrev-ref HEAD 2>/dev/null`.strip.presence
    rescue StandardError
      nil
    end) ||
    "main"
  ).freeze

  class << self
    def sha = SHA
    def short_sha = SHORT_SHA
    def version = VERSION
    def branch = BRANCH

    # Compact display string for the footer chip — "v199 · main".
    def label = "#{version} · #{branch}"

    # Long-form, surfaced as the chip's `title=` tooltip.
    def title
      parts = []
      parts << "Release #{version}" if version != "dev"
      parts << "Branch #{branch}"
      parts << "Commit #{short_sha}" if short_sha
      parts.join(" · ")
    end

    def commit_url = sha ? "#{REPO_URL}/commit/#{sha}" : REPO_URL
  end
end
