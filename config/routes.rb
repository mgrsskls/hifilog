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

  get 'newsletters/unsubscribe', to: 'user#newsletter_unsubscribe', as: :newsletters_unsubscribe

  scope '/dashboard', as: :dashboard do
    root 'user#dashboard'
    get 'products', to: 'possessions#current', as: :products
    get 'previous-products', to: 'possessions#previous', as: :prev_owneds
    get 'bookmarks', to: 'user#bookmarks', as: :bookmarks
    get 'bookmarks/new', to: 'bookmark_lists#new', as: :new_bookmark_list
    get 'bookmarks/:id', to: 'bookmark_lists#show', as: :bookmark_list
    get 'bookmarks/:id/edit', to: 'bookmark_lists#edit', as: :edit_bookmark_list
    get 'contributions', to: 'user#contributions', as: :contributions
    get 'custom-products', to: 'custom_products#index', as: :custom_products
    get 'custom-products/new', to: 'custom_products#new', as: :new_custom_product
    get 'custom-products/:id/edit', to: 'custom_products#edit', as: :edit_custom_product
    get 'history', to: 'user#history', as: :history
    scope 'statistics', as: :statistics do
      root 'statistics#current'
      get 'total', to: 'statistics#total', as: :total
      get 'yearly', to: 'statistics#yearly', as: :yearly
    end
    resources :setups, only: [:index, :show, :new, :edit]
    resources :notes, only: [:index, :show]
  end
  get '/user/has', to: 'user#has', as: :has
  get '/user/counts', to: 'user#counts', as: :counts

  resources :bookmark_lists, only: [:create, :update, :destroy]
  resources :notes, only: [:create, :destroy, :update]
  resources :custom_products, only: [:create, :destroy, :update]
  resources :possessions, only: [:create, :destroy, :update] do
    post 'move_to_prev_owneds', to: 'possessions#move_to_prev_owneds'
  end
  resources :setup_possessions, only: [:destroy]
  resources :bookmarks, only: [:create, :update, :destroy]
  resources :setups, only: [:create, :update, :destroy]
  resources :users, only: [:index, :show] do
    get '/custom-products/:id', to: 'custom_products#show', as: :custom_product
    get '/previous-products', to: 'users#prev_owneds'
    get '/setups/:setup', to: 'users#show', as: :setup
    get '/history', to: 'users#history', as: :history
    get '/contributions', to: 'users#contributions', as: :contributions
  end
  post '/app_news/mark_as_read', to: 'app_news#mark_as_read'

  # /brands
  # /brands/:brand
  # /brands/:brand/:category
  get '/all_brands', controller: :brands, action: :all, constraints: lambda { |req| req.format == :json }
  resources :brands do
    get '/products', action: :products
    get '/changelog', action: :changelog
  end

  # /products
  resources :products, only: [:show, :index, :new, :create, :edit, :update] do
    get '/changelog', action: :changelog
    get '/notes', to: 'notes#new', as: :new_notes
    resources :product_variants, only: [:create, :update]
    get '/variants/new', to: 'product_variants#new'
    get '/v/:id', to: 'product_variants#show', as: :variant
    get '/v/:id/edit', to: 'product_variants#edit', as: :edit_variant
    get '/v/:id/changelog', to: 'product_variants#changelog', as: :variant_changelog
    get '/v/:id/notes', to: 'notes#new', as: :new_variant_notes
  end

  get '/search', to: "search#results"

  root "application#index"

  get '/sitemap.xml', to: 'sitemap#xml', as: :sitemap
  get '/feed.rss', to: 'feed#rss', as: :rss

  get '/changelog', to: 'static#changelog'
  get '/about', to: 'static#about'
  get '/privacy-policy', to: 'static#privacy_policy'
  get '/imprint', to: 'static#imprint'

  get '/', to: 'application#not_found', via: [:post, :put, :patch, :delete, :options]
  get '*url', to: 'application#not_found', via: :all, constraints: lambda { |req| req.format == :html }
end
