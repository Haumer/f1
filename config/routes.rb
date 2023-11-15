Rails.application.routes.draw do
  root to: "pages#home"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  # root "articles#index"

  mount Blazer::Engine, at: "blazer"

  resources :drivers do
    collection do 
      get 'peak_elo', to: 'drivers#peak_elo'
      get 'current_active_elo', to: 'drivers#current_active_elo'
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
  resources :constructors
  resources :seasons
  resources :circuits
end
