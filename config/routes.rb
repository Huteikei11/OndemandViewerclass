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

  # API routes for session management
  namespace :api do
    resources :sessions, only: [] do
      member do
        post :activate
        post :deactivate
      end
    end

    resources :videos, only: [] do
      member do
        post :new_session
      end
    end
  end

  # Video resources
  resources :videos do
    # Nested resources for questions
    resources :questions, only: [ :create, :edit, :update, :destroy ] do
      resources :options, only: [ :create, :update, :destroy ]
      resources :user_responses, only: [ :create ]
    end

    # Custom routes for player view
    member do
      get "player"
      post "duplicate"
    end

    # Video management routes (nested under videos)
    get "management/analytics", to: "video_management#analytics", as: "management_analytics"
    get "management/timeline", to: "video_management#timeline", as: "management_timeline"
    get "management/add_manager", to: "video_management#add_manager", as: "management_add_manager"
    post "management/add_manager", to: "video_management#add_manager"
    get "management/session/:session_id", to: "video_management#session_detail", as: "management_session_detail"
    get "management/session/:session_id/events", to: "video_management#session_events_page", as: "management_session_events"
    delete "management/session/:session_id/events", to: "video_management#destroy_events", as: "management_destroy_events"
    patch  "management/session/:session_id/group",  to: "video_management#update_session_group", as: "management_update_session_group"
    get  "management/cluster_sessions",    to: "video_management#cluster_sessions",    as: "management_cluster_sessions"
    get  "management/session_metrics",     to: "video_management#session_metrics",     as: "management_session_metrics"
    post "management/bulk_update_groups",  to: "video_management#bulk_update_groups",  as: "management_bulk_update_groups"
    post "management/reset_all_groups",    to: "video_management#reset_all_groups",    as: "management_reset_all_groups"
    post "management/save_session", to: "video_management#save_session_data", as: "management_save_session"
    delete "management/session/:session_id", to: "video_management#destroy_session", as: "management_destroy_session"

    # CSV export routes
    get "management/export_summary", to: "video_management#export_summary", as: "management_export_summary"
    get "management/export_questions", to: "video_management#export_questions", as: "management_export_questions"
    get "management/export_sessions", to: "video_management#export_sessions", as: "management_export_sessions"
    get "management/export_events", to: "video_management#export_events", as: "management_export_events"
    get "management/export_pauses",          to: "video_management#export_pauses",          as: "management_export_pauses"
    get "management/export_classification",  to: "video_management#export_classification",  as: "management_export_classification"
    get "management/export_session_detail/:session_id", to: "video_management#export_session_detail", as: "management_export_session_detail"
    get "management/export_session_events/:session_id", to: "video_management#export_session_events", as: "management_export_session_events"
  end

  # Batch delete sessions (outside videos scope)
  post "video_management/delete_sessions", to: "video_management#delete_sessions"
  post "video_management/delete_response", to: "video_management#delete_response"
  post "video_management/delete_responses", to: "video_management#delete_responses"
  get "video_management/get_chart_data", to: "video_management#get_chart_data"
end
