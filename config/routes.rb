Rails.application.routes.draw do
  devise_for :users
  
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Root path
  root "video_access#index"
  
  # Video access routes
  get "video_access", to: "video_access#index"
  get "video_access/new", to: "video_access#new"
  post "video_access/create", to: "video_access#create"

  # Video resources
  resources :videos do
    # Nested resources for questions and notes
    resources :questions, only: [ :create, :edit, :update, :destroy ] do
      resources :options, only: [ :create, :update, :destroy ]
      resources :user_responses, only: [ :create ]
    end
    resources :notes, only: [ :create, :update, :destroy ]

    # Custom routes for player view
    member do
      get "player"
    end
    
    # Video management routes (nested under videos)
    get "management/analytics", to: "video_management#analytics", as: "management_analytics"
    get "management/add_manager", to: "video_management#add_manager", as: "management_add_manager"
    post "management/add_manager", to: "video_management#add_manager"
  end
end
