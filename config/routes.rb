Rails.application.routes.draw do
  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)
  devise_for :users

  resources :manufacturers do
    resources :products
  end
  resources :categories do
    resources :sub_categories do
      get "/", to: "categories#sub_category"
    end
  end
  resources :products
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  root "application#index"
end
