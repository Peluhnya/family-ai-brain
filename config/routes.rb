Rails.application.routes.draw do
  root "pages#home"
  get "hotwire-native/configuration", to: "hotwire_native#configuration", defaults: { format: :json }, as: :hotwire_native_configuration
  resources :accounts do
    post :test_ai_connection, on: :member
    resources :families, only: %i[index new create]
  end
  resources :families, only: %i[show edit update destroy] do
    post :run_automation_rules, on: :member
    get ":tab", on: :member, action: :show, as: :tab, constraints: {
      tab: /chat|calendar|documents|reminders|connections|events|tasks|automations|knowledge|logs|ai_logs|members/
    }
    resources :family_members, only: %i[create update destroy]
    resources :ai_interactions, only: :create
    resources :ai_action_proposals, only: [] do
      post :confirm, on: :member
      post :reject, on: :member
    end
    resources :conversations, only: [] do
      get :messages, on: :member
    end
    resources :life_logs, only: %i[create update destroy]
    resources :family_knowledge, only: %i[create update destroy]
    resources :events, only: %i[create update destroy]
    resources :calendar_connections, only: %i[create update destroy]
    post "calendar_connections/connect_google", to: "calendar_connections#connect_google", as: :connect_google_calendar
    post "calendar_connections/connect_outlook", to: "calendar_connections#connect_outlook", as: :connect_outlook_calendar
    post "calendar_connections/connect_apple", to: "calendar_connections#connect_apple", as: :connect_apple_calendar
    resources :documents, only: %i[create update destroy]
    resources :reminders, only: %i[create update destroy]
    resources :automation_rules, only: %i[create update destroy]
    resources :tasks, only: %i[create update destroy]
  end
  resources :calendar_connections, only: [] do
    get :google_callback, on: :collection
    get :select_google_calendar, on: :member
    post :update_google_calendar, on: :member
    post :authorize_google, on: :member
    get :outlook_callback, on: :collection
    get :select_outlook_calendar, on: :member
    post :update_outlook_calendar, on: :member
    post :authorize_outlook, on: :member
    get :select_apple_calendar, on: :member
    post :update_apple_calendar, on: :member
    post :sync, on: :member
  end
  resources :automation_rules, only: [] do
    post :run_now, on: :member
    patch :toggle_active, on: :member
  end
  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
