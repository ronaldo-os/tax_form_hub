Rails.application.routes.draw do
  resources :locations
  get "invoices/index"
  devise_for :users, controllers: {
    registrations: 'users/registrations'
  }

  # Alias to create a clean /profile/edit route
  as :user do
    get 'profile/edit' => 'users/registrations#edit', as: :edit_profile
  end

  root "pages#home"

  get "pages/home"

  namespace :admin do
    resources :tax_submissions, only: [:index, :show, :update]
  end

  resources :tax_submissions, only: [:new, :create, :show, :destroy]
  resources :invoices, only: [:index, :create, :new, :show]
  resources :companies

  patch '/tax_submissions/:id', to: 'pages#update', as: 'update_tax_submission'

  # Optional: health check + PWA
  get "up" => "rails/health#show", as: :rails_health_check
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
end
