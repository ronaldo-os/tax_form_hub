Rails.application.routes.draw do
  namespace :admin do
    get "tax_submissions/index"
    get "tax_submissions/update"
  end
  get "tax_submissions/new"
  get "tax_submissions/create"
  devise_for :users
  get "pages/home"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # Defines the root path route ("/")
  # root "posts#index"

  root "pages#home"

  namespace :admin do
    resources :tax_submissions, only: [:index, :show, :update]
  end


  resources :tax_submissions, only: [:new, :create]
end
