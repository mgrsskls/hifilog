Rails.application.routes.draw do
  devise_for :admin_users, ActiveAdmin::Devise.config

  ActiveAdmin.routes(self)

  devise_for :users, controllers: {
    passwords: "users/passwords",
    registrations: "users/registrations",
    sessions: "users/sessions",
  }

  scope '/user/:user_name', as: :user do
    get '/', to: 'user#products'
    get ':category', to: 'user#products', as: :products_category
  end

  scope '/dashboard', as: :dashboard do
    root 'user#dashboard'
    get 'products', to: 'user#products', as: :products
    get 'bookmarks', to: 'user#bookmarks', as: :bookmarks
    get 'products/:category', to: 'user#products', as: :products_category
    resources :setups, only: [:index, :show, :create, :destroy]
  end

  resources :user_products, only: [:create, :destroy], as: :owned_products
  resources :setup_products, only: [:create, :destroy]
  resources :bookmarks, only: [:create, :destroy]

  # /categories
  # /categories/:category
  resources :categories, only: [:index, :show] do
    # /categories/:category/:sub_category
    resources :sub_categories, path: '', only: [:show]
  end

  # /brands
  # /brands/:brand
  # /brands/:brand/:category
  resources :brands do
    get '/changelog', action: :changelog
  end

  # /products
  resources :products, only: [:index, :new, :create, :update]

  # /:brand/:product
  get ':brand_id/:id', as: :brand_product, to: 'products#show'
  get ':brand_id/:id/edit', as: :edit_brand_product, to: 'products#edit'
  get ':brand_id/:id/changelog', as: :changelog_brand_product, to: 'products#changelog'

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
