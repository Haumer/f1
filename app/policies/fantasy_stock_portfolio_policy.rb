# frozen_string_literal: true

class FantasyStockPortfolioPolicy < ApplicationPolicy
  def show?
    owner?
  end

  def market?
    owner?
  end

  def buy?
    owner?
  end

  def sell?
    owner?
  end

  def short_open?
    owner?
  end

  def short_close?
    owner?
  end

  private

  def owner?
    record.user_id == user.id
  end
end
