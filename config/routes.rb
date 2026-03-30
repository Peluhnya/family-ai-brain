Rails.application.routes.draw do
  root "pages#home"
  resources :accounts do
    post :test_ai_connection, on: :member
    resources :families, only: %i[index new create]
  end
  resources :families, only: %i[show edit update destroy] do
    post :run_automation_rules, on: :member
    get ":tab", on: :member, action: :show, as: :tab, constraints: {
      tab: /chat|documents|reminders|connections|events|tasks|automations|knowledge|logs|members/
    }
    resources :family_members, only: :create
    resources :ai_interactions, only: :create
    resources :life_logs, only: :create
    resources :family_knowledge, only: :create
    resources :events, only: :create
    resources :calendar_connections, only: :create
    resources :documents, only: :create
    resources :reminders, only: :create
    resources :automation_rules, only: :create
    resources :tasks, only: :create
  end
  resources :calendar_connections, only: [] do
    get :google_callback, on: :collection
    get :select_google_calendar, on: :member
    post :update_google_calendar, on: :member
    post :authorize_google, on: :member
    post :sync, on: :member
  end
  resources :automation_rules, only: [] do
    post :run_now, on: :member
  end
  resources :family_members, only: %i[edit update destroy]
  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

end
