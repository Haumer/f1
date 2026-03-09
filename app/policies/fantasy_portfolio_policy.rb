# frozen_string_literal: true

class FantasyPortfolioPolicy < ApplicationPolicy
  def show?
    owner?
  end

  def market?
    owner?
  end

  def buy?
    owner?
  end

  def buy_multiple?
    owner?
  end

  def sell?
    owner?
  end

  def buy_team?
    owner?
  end

  def unified_trade?
    owner?
  end

  private

  def owner?
    record.user_id == user.id
  end
end
