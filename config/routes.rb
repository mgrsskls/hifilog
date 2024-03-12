Rails.application.routes.draw do
  devise_for :user, controllers: {
    confirmations: "users/confirmations",
    passwords: "users/passwords",
    registrations: "users/registrations",
    sessions: "users/sessions",
  }

  devise_for :admin_users, ActiveAdmin::Devise.config

  ActiveAdmin.routes(self)

  direct :cdn_image do |model, options|
    expires_in = options.delete(:expires_in) { ActiveStorage.urls_expire_in }

    if model.respond_to?(:signed_id)
      route_for(
        :rails_service_blob_proxy,
        model.signed_id(expires_in: expires_in),
        model.filename,
        options.merge(host: ENV['CDN_HOST'], port: ENV['CDN_PORT'])
      )
    else
      signed_blob_id = model.blob.signed_id(expires_in: expires_in)
      variation_key  = model.variation.key
      filename       = model.blob.filename

      route_for(
        :rails_blob_representation_proxy,
        signed_blob_id,
        variation_key,
        filename,
        options.merge(host: ENV['CDN_HOST'], port: ENV['CDN_PORT'])
      )
    end
  end

  scope '/dashboard', as: :dashboard do
    root 'user#dashboard'
    get 'products', to: 'user#products', as: :products
    get 'bookmarks', to: 'user#bookmarks', as: :bookmarks
    get 'previous', to: 'user#prev_owneds', as: :prev_owneds
    get 'contributions', to: 'user#contributions', as: :contributions
    resources :setups, only: [:index, :show, :create, :destroy]
  end

  resources :possessions, only: [:create, :destroy, :update]
  resources :setup_possessions, only: [:create, :destroy]
  resources :bookmarks, only: [:create, :destroy]
  resources :prev_owneds, only: [:create, :destroy]
  resources :users, only: [:index, :show] do
    get '/previous-products', to: 'users#prev_owneds'
    get '/setups/:setup', to: 'users#show', as: :setup
  end

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
    resources :product_variants, only: [:create, :update]
    get '/variants/new', to: 'product_variants#new'
    get '/v/:variant', to: 'product_variants#show', as: :variant
    get '/v/:variant/edit', to: 'product_variants#edit', as: :edit_variant
    get '/v/:variant/changelog', to: 'product_variants#changelog', as: :variant_changelog
  end

  get '/search', to: "search#results"

  root "application#index"

  get '/sitemap.xml', to: 'sitemap#xml'
  get '/feed.rss', to: 'feed#rss', as: :rss

  get '/changelog', to: 'static#changelog'
  get '/about', to: 'static#about'
  get '/privacy-policy', to: 'static#privacy_policy'
  get '/imprint', to: 'static#imprint'

  get '/', to: 'application#not_found', via: [:post, :put, :patch, :delete, :options]
  get '*url', to: 'application#not_found', via: :all, constraints: lambda { |req| req.format == :html }
end
