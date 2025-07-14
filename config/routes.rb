Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Root path
  root "videos#index"
  
  # Video resources
  resources :videos do
    # Nested resources for questions and notes
    resources :questions, only: [:create, :update, :destroy] do
      resources :options, only: [:create, :update, :destroy]
      resources :user_responses, only: [:create]
    end
    resources :notes, only: [:create, :update, :destroy]
    
    # Custom routes for player view
    member do
      get 'player'
    end
  end
end
