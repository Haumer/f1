class PagesController < ApplicationController
  def home
    @season = Season.sorted_by_year.first
  end
end
