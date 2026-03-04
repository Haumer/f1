class ApplicationController < ActionController::Base
  include AccentColorable

  before_action :set_current_champion_accent
end
