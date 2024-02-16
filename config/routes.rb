Rails.application.routes.draw do
  devise_for :admin_users, ActiveAdmin::Devise.config

  ActiveAdmin.routes(self)

  devise_for :users, controllers: {
    passwords: "users/passwords",
    registrations: "users/registrations",
    sessions: "users/sessions",
  }

  scope '/dashboard', as: :dashboard do
    root 'user#dashboard'
    get 'products', to: 'user#products', as: :products
    get 'bookmarks', to: 'user#bookmarks', as: :bookmarks
    get 'prev_owneds', to: 'user#prev_owneds', as: :prev_owneds
    get 'contributions', to: 'user#contributions', as: :contributions
    get 'products/:category', to: 'user#products', as: :products_category
    resources :setups, only: [:index, :show, :create, :destroy]
  end

  resources :user_products, only: [:create, :destroy], as: :owned_products
  resources :setup_products, only: [:create, :destroy]
  resources :bookmarks, only: [:create, :destroy]
  resources :prev_owneds, only: [:create, :destroy]
  resources :users, only: [:index, :show]

  # /brands
  # /brands/:brand
  # /brands/:brand/:category
  get '/all_brands', controller: :brands, action: :all, constraints: lambda { |req| req.format == :json }
  resources :brands do
    get '/changelog', action: :changelog
  end

  # /products
  resources :products, only: [:show, :index, :new, :create, :edit, :update] do
    get '/changelog', action: :changelog
  end

  get '/search', to: "search#results"

  root "application#index"

  get '/sitemap.xml', to: 'sitemap#xml'
  get '/feed.rss', to: 'feed#rss', as: :rss

  get '/changelog', to: 'static#changelog'
  get '/about', to: 'static#about'
  get '/privacy-policy', to: 'static#privacy_policy'

  get '/', to: 'application#not_found', via: [:post, :put, :patch, :delete, :options]
  get '*url', to: 'application#not_found', via: :all, format: 'html'
end
