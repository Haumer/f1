Rails.application.routes.draw do
  devise_for :users
  get "users/username_available", to: "users#username_available"
  root to: "pages#home"

  namespace :admin do
    root to: 'dashboard#index'
    resource :settings, only: [:show, :update]
    resources :operations, only: [:index, :create]
    resources :alerts, only: [:update]
    resources :analytics, only: [:index, :show] do
      collection do
        post :toggle_exclusion
      end
    end
    resources :experiments, only: [:index]
  end
  get 'elo', to: 'pages#elo', as: :elo
  get 'about', to: 'pages#about', as: :about
  get 'terms', to: 'pages#terms', as: :terms
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
    member do
      get 'preview/:username', to: 'predictions#show', as: :preview
      get 'preview/:username/og.png', to: 'predictions#og_image', as: :preview_og_image
    end
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
  get 'stats/race_wins', to: 'stats#race_wins', as: :race_wins
  get 'stats/champion_timeline', to: 'stats#champion_timeline', as: :champion_timeline

  # Fantasy user pages (must be before resources to avoid :id conflicts)
  get  'fantasy/u/:username',         to: 'fantasy_portfolios#overview',  as: :fantasy_overview
  post 'fantasy/toggle_public',       to: 'fantasy_portfolios#toggle_public', as: :toggle_public_profile

  resources :fantasy_portfolios, path: 'fantasy', only: [:new, :create] do
    member do
      get :market
      post :buy
      post :buy_multiple
      post :sell
      post :buy_team
      post :unified_trade
    end
    collection do
      get :leaderboard
    end
  end

  resources :fantasy_stock_portfolios, path: 'stocks', only: [:new, :create] do
    member do
      get :market
      post :buy
      post :sell
      post :short_open
      post :short_close
      post :buy_batch
    end
    collection do
      get :leaderboard
    end
  end

  get 'leaderboard', to: 'fantasy_portfolios#combined_leaderboard', as: :combined_leaderboard

  # Race Picks
  resource :race_picks, only: [:edit, :update], path: 'picks' do
    post :stash, on: :collection
  end

  # User account settings
  get   'u/:username', to: 'users#show',   as: :user_settings
  patch 'u/:username', to: 'users#update'
end
