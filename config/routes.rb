Rails.application.routes.draw do
  devise_for :users
  get "users/username_available", to: "users#username_available"
  root to: "pages#home"

  namespace :admin do
    root to: 'dashboard#index'
    resource :settings, only: [:show, :update]
    resources :operations, only: [:index, :create]
    resources :alerts, only: [:update]
  end
  get 'elo', to: 'pages#elo', as: :elo
  get 'about', to: 'pages#about', as: :about
  get 'fantasy_guide', to: 'pages#fantasy_guide', as: :fantasy_guide

  authenticate :user, ->(u) { u.admin? } do
    mount Blazer::Engine, at: "blazer"
  end

  resources :drivers, only: [:index, :show] do
    collection do
      get 'grid', to: 'drivers#grid'
      get 'peak_elo', to: 'drivers#peak_elo'
      get 'current_active_elo', to: 'drivers#current_active_elo'
      get 'compare', to: 'drivers#compare'
      get 'search', to: 'drivers#search'
      get 'by_nationality', to: 'drivers#by_nationality'
    end
  end
  resources :races, only: [:index, :show] do
    collection do
      get 'calendar', to: 'races#calendar'
      get 'highest_elo', to: 'races#highest_elo'
      get 'podiums', to: 'races#podiums'
      get 'winners', to: 'races#winners'
    end
  end
  resources :constructors, only: [:index, :show] do
    member do
      post :support
    end
    collection do
      get 'grid', to: 'constructors#grid'
      get 'elo_rankings', to: 'constructors#elo_rankings'
      get 'families', to: 'constructors#families'
      get 'best_pairings', to: 'constructors#best_pairings'
    end
  end
  resources :seasons, only: [:index, :show]
  resources :circuits, only: [:index, :show]

  get 'stats', to: 'stats#index', as: :stats
  get 'stats/elo_milestones', to: 'stats#elo_milestones', as: :elo_milestones
  get 'stats/badges', to: 'stats#badges', as: :badges
  get 'stats/fan_standings', to: 'stats#fan_standings', as: :fan_standings

  resources :fantasy_portfolios, path: 'fantasy', only: [:new, :create, :show] do
    member do
      get :market
      post :buy
      post :buy_multiple
      post :sell
      post :buy_team
    end
    collection do
      get :leaderboard
    end
  end

  resources :fantasy_stock_portfolios, path: 'stocks', only: [:new, :create, :show] do
    member do
      get :market
      post :buy
      post :sell
      post :short_open
      post :short_close
    end
    collection do
      get :leaderboard
    end
  end

  get 'leaderboard', to: 'fantasy_portfolios#combined_leaderboard', as: :combined_leaderboard
end
