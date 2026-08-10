Rails.application.routes.draw do
  devise_for :users, controllers: { registrations: "users/registrations" }
  get "users/username_available", to: "users#username_available"
  root to: "pages#home"

  get 'sitemap.xml', to: 'sitemaps#index', defaults: { format: 'xml' }, as: :sitemap

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
  get 'impressum', to: 'pages#impressum', as: :impressum
  get 'fantasy_guide', to: 'pages#fantasy_guide', as: :fantasy_guide

  # Head-to-Head: pairwise driver-preference game, playable without an account.
  get  'head-to-head',                to: 'head_to_head#show',    as: :head_to_head
  post 'head-to-head/start',          to: 'head_to_head#start',   as: :start_head_to_head
  post 'head-to-head/pick',           to: 'head_to_head#pick',    as: :pick_head_to_head
  get  'head-to-head/finish',         to: 'head_to_head#finish',  as: :finish_head_to_head
  get  'head-to-head/results',        to: 'head_to_head#results', as: :head_to_head_results
  get  'head-to-head/:year',          to: 'head_to_head#show',    constraints: { year: /\d{4}/ }, as: :head_to_head_year
  get  'head-to-head/:year/results',  to: 'head_to_head#results', constraints: { year: /\d{4}/ }, as: :head_to_head_results_year

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
  get 'stats/title_chase(/:season_year)', to: 'stats#title_chase', as: :title_chase

  # Fantasy user pages (must be before resources to avoid :id conflicts)
  get  'fantasy/u/:username',         to: 'fantasy_portfolios#overview',  as: :fantasy_overview
  get  'fantasy/u/:username/picks/:race_id', to: 'race_picks#results', as: :race_pick_results
  get  'fantasy/u/:username/picks/:race_id/compare', to: 'race_picks#compare', as: :race_pick_compare
  post 'fantasy/toggle_public',       to: 'fantasy_portfolios#toggle_public', as: :toggle_public_profile

  resources :fantasy_portfolios, path: 'fantasy', only: [:new, :create] do
    collection do
      get :leaderboard
    end
  end

  resources :fantasy_stock_portfolios, path: 'stocks', only: [] do
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

  # Driver Cards (collectible cards earned from correct race picks). Lives
  # under /fantasy/u/:username so the URL says whose collection it is.
  # `/cards` redirects to the signed-in user's own collection.
  get  'fantasy/u/:username/cards',           to: 'driver_cards#index',   as: :driver_cards
  post 'fantasy/u/:username/cards/combine',   to: 'driver_cards#combine', as: :combine_driver_cards
  get  'fantasy/u/:username/cards/:id',       to: 'driver_cards#show',    as: :driver_card
  get  'cards', to: redirect { |_p, req|
    user = req.env['warden']&.user
    user ? "/fantasy/u/#{user.username}/cards" : "/users/sign_in"
  }

  # Activity feed (credits + cards + achievements). Owner-only.
  get 'fantasy/u/:username/activity', to: 'fantasy_activity#index', as: :fantasy_activity

  # User public profile + settings
  get   'u/:username',          to: 'users#profile',  as: :user_profile
  get   'u/:username/settings', to: 'users#settings', as: :user_settings
  patch 'u/:username/settings', to: 'users#update'

  # Reactions (polymorphic toggle)
  post 'reactions/:reactable_type/:reactable_id/:kind',
       to: 'reactions#toggle', as: :toggle_reaction
end
