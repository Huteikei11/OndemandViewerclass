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

  # Viewing history route
  get "viewing_history", to: "viewing_history#index", as: "viewing_history"
  get "viewing_history/session/:id", to: "viewing_history#session_detail", as: "viewing_history_session_detail"
  get "viewing_history/export_detail/:id", to: "viewing_history#export_session_detail", as: "viewing_history_export_detail"
  get "viewing_history/export_events/:id", to: "viewing_history#export_session_events", as: "viewing_history_export_events"

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
    get "management/timeline", to: "video_management#timeline", as: "management_timeline"
    get "management/add_manager", to: "video_management#add_manager", as: "management_add_manager"
    post "management/add_manager", to: "video_management#add_manager"
    get "management/session/:session_id", to: "video_management#session_detail", as: "management_session_detail"
    post "management/save_session", to: "video_management#save_session_data", as: "management_save_session"

    # CSV export routes
    get "management/export_summary", to: "video_management#export_summary", as: "management_export_summary"
    get "management/export_questions", to: "video_management#export_questions", as: "management_export_questions"
    get "management/export_session_detail/:session_id", to: "video_management#export_session_detail", as: "management_export_session_detail"
    get "management/export_session_events/:session_id", to: "video_management#export_session_events", as: "management_export_session_events"
  end
end
