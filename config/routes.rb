Rails.application.routes.draw do
  get "recurring_invoices/index"
  get "recurring_invoices/disable"
  resources :locations
  get "invoices/index"
  devise_for :users, controllers: {
    registrations: 'users/registrations',
    passwords: "users/passwords"
  }

  # Alias to create a clean /profile/edit route
  as :user do
    get   'profile/edit' => 'users/registrations#edit',   as: :edit_profile
    patch 'profile/edit' => 'users/registrations#update', as: :profile
    put   'profile/edit' => 'users/registrations#update'
  end

  root "tax_submissions#home"
  get "tax_submissions/home"

  resources :tax_submissions, only: [:new, :create, :show, :destroy, :update]

  namespace :admin do
    resources :tax_submissions, only: [:index, :show, :update]
  end

  namespace :admin do
    resources :tax_submissions, only: [:index, :show, :update]
  end

  resources :invoices, only: [:index, :show, :new, :create, :destroy]

  resources :invoices do
    member do
      patch :approve
      patch :deny
      patch :archive
      patch :unarchive
      patch :mark_as_paid
      post  :duplicate_as_purchase
    end
  end

  resources :invoices do
    collection do
      post :create_and_send
    end
  end


  resources :companies do
    resources :recommendations, only: [:create]
  end


  resources :recurring_invoices, only: [:index, :update, :destroy] do
    collection do
      patch :enable
      patch :disable
    end
  end

  # Optional: health check + PWA
  get "up" => "rails/health#show", as: :rails_health_check
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
end
