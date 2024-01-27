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
    resources :setups
  end

  resources :user_products, only: [:create, :destroy], as: :owned_products
  resources :setup_products, only: [:create, :destroy]
  resources :bookmarks, only: [:create, :destroy]

  # /categories
  # /categories/:category
  resources :categories, only: [:index, :show] do
    # /categories/:category/:sub_category
    # /categories/:category/:sub_category/a
    # /categories/:category/:sub_category/a/page/2
    # /categories/:category/:sub_category/page/2
    resources :sub_categories, path: '', only: [:show] do
      get ':id/:letter', to: 'sub_categories#show', on: :collection, as: :letter, constraints: { letter: /[a-z]/ }
      get ':id/:letter/page/:page', to: 'sub_categories#show', on: :collection, constraints: { letter: /[a-z]/ }
      get ':id/page/:page', to: 'sub_categories#show', on: :collection
    end
  end

  # /brands
  # /brands/a
  # /brands/a/page/2
  # /brands/page/2
  # /brands/:brand
  # /brands/:brand/:category
  resources :brands, only: [:index, :show, :new, :create] do
    get ':letter', action: :index, on: :collection, as: :letter, constraints: { letter: /[a-z]/ }
    get ':letter/page/:page', action: :index, on: :collection, constraints: { letter: /[a-z]/ }
    get 'page/:page', action: :index, on: :collection
    get ':category', action: :category, as: :category
  end

  # /products
  # /products/a
  # /products/a/page/2
  # /products/page/2
  resources :products, only: [:index, :new, :create] do
    get ':letter', action: :index, on: :collection, as: :letter, constraints: { letter: /[a-z]/ }
    get ':letter/page/:page', action: :index, on: :collection, constraints: { letter: /[a-z]/ }
    get 'page/:page', action: :index, on: :collection
  end

  # /:brand/:product
  get ':brand_id/:id', as: :brand_product, to: 'products#show', constraints: { id: /.{2,}/ }

  get '/search', to: "search#results"

  root "application#index"

  get '/sitemap.xml', to: 'application#sitemap'
  get '/feed.rss', to: 'application#feed', as: :rss

  get '/changelog', to: 'static#changelog'
  get '/about', to: 'static#about'
  get '/privacy-policy', to: 'static#privacy_policy'

  get '/', to: 'application#not_found', via: [:post, :put, :patch, :delete, :options]
  get '*url', to: 'application#not_found', via: :all, format: 'html'
end
