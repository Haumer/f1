Rails.application.routes.draw do
  devise_for :users
  root to: "pages#home"

  namespace :admin do
    root to: 'dashboard#index'
    resource :settings, only: [:show, :update]
    resources :operations, only: [:index, :create]
  end
  get 'about', to: 'pages#about'
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  # root "articles#index"

  mount Blazer::Engine, at: "blazer"

  resources :drivers do
    collection do
      get 'peak_elo', to: 'drivers#peak_elo'
      get 'current_active_elo', to: 'drivers#current_active_elo'
      get 'compare', to: 'drivers#compare'
      get 'search', to: 'drivers#search'
      get 'by_nationality', to: 'drivers#by_nationality'
    end
  end
  resources :race_results
  resources :races do
    collection do
      get 'highest_elo', to: 'races#highest_elo'
      get 'podiums', to: 'races#podiums'
      get 'winners', to: 'races#winners'
    end
  end
  resources :constructors do
    collection do
      get 'elo_rankings', to: 'constructors#elo_rankings'
      get 'families', to: 'constructors#families'
      get 'best_pairings', to: 'constructors#best_pairings'
    end
  end
  resources :seasons
  resources :circuits

  get 'stats/elo_milestones', to: 'stats#elo_milestones', as: :elo_milestones
  get 'stats/badges', to: 'stats#badges', as: :badges

  resources :fantasy_portfolios, path: 'fantasy', only: [:new, :create, :show] do
    member do
      get :market
      post :buy
      post :sell
    end
    collection do
      get :leaderboard
    end
  end
end
