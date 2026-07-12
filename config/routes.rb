Rails.application.routes.draw do
  devise_for :user, controllers: {
    confirmations: "users/confirmations",
    passwords: "users/passwords",
    registrations: "users/registrations",
    sessions: "users/sessions",
    unlocks: "users/unlocks",
  }

  devise_for :admin_users, ActiveAdmin::Devise.config

  ActiveAdmin.routes(self)

  authenticate :admin_user do
    mount ActiveAnalytics::Engine, at: "analytics"
    mount PgHero::Engine, at: "pghero"
  end

  direct :cdn_image do |model, options|
    expires_in = options.delete(:expires_in) { ActiveStorage.urls_expire_in }

    if model.respond_to?(:signed_id)
      route_for(
        :rails_service_blob_proxy,
        model.signed_id(expires_in: expires_in),
        model.filename,
        **options
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
        **options
      )
    end
  end

  resource :privacy_policy_acceptance, only: %i[new create destroy]

  match 'newsletters/unsubscribe', to: 'user#newsletter_unsubscribe', via: %i[get post], as: :newsletters_unsubscribe
  match 'follow-notifications/unsubscribe', to: 'user#follow_notification_unsubscribe', via: %i[get post],
                                            as: :follow_notifications_unsubscribe

  scope '/dashboard', as: :dashboard do
    root 'user#dashboard'
    get 'products', to: 'possessions#current', as: :products
    get 'previous-products', to: 'possessions#previous', as: :prev_owneds
    get 'events', to: 'user#events', as: :events
    get 'events/past', to: 'user#past_events', as: :past_events
    get 'bookmarks', to: 'user#bookmarks', as: :bookmarks
    get 'bookmarks/:id', to: 'user#bookmarks', as: :bookmark_list
    get 'bookmarks/lists/new', to: 'bookmark_lists#new', as: :new_bookmark_list
    get 'bookmarks/lists/:id/edit', to: 'bookmark_lists#edit', as: :edit_bookmark_list
    get 'contributions', to: 'user#contributions', as: :contributions
    get 'custom-products', to: 'custom_products#index', as: :custom_products
    get 'custom-products/new', to: 'custom_products#new', as: :new_custom_product
    get 'custom-products/:id/edit', to: 'custom_products#edit', as: :edit_custom_product
    get 'history', to: 'user#history', as: :history
    get 'feed', to: 'user#feed', as: :feed
    get 'following', to: 'user#following', as: :following
    get 'followers', to: 'user#followers', as: :followers
    get 'blocked', to: 'user#blocked', as: :blocked
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
    get '/collection', to: 'users#collection', as: :collection
    get '/custom-products/:id', to: 'custom_products#show', as: :custom_product
    get '/previous-products', to: 'users#prev_owneds'
    get '/setups/:setup', to: 'users#collection', as: :setup
    get '/history', to: 'users#history', as: :history
    get '/activity', to: 'users#activity'
    get '/contributions', to: 'users#contributions', as: :contributions
  end
  post '/app_news/mark_as_read', to: 'app_news#mark_as_read'

  # /brands
  # /brands/:brand
  # /brands/c/:category_slug[/:sub_category_slug]
  get '/all_brands', controller: :brands, action: :all, constraints: lambda { |req| req.format == :json }
  get '/brands/c/:category_slug/:sub_category_slug', to: 'brands#index', as: :brands_subcategory
  get '/brands/c/:category_slug', to: 'brands#index', as: :brands_category

  resources :brands do
    get 'products/c/:category_slug/:sub_category_slug', action: :products, as: :brand_products_subcategory
    get 'products/c/:category_slug', action: :products, as: :brand_products_category
    get 'products', action: :products
    get 'changelog', action: :changelog
  end

  # Product catalog (/products[/c/…]) — must be before resources :products
  get '/products/c/:category_slug/:sub_category_slug', to: 'product_items#index', as: :products_subcategory
  get '/products/c/:category_slug', to: 'product_items#index', as: :products_category
  get '/products', to: 'product_items#index', as: :products

  # /products/:id (resource CRUD…)
  resources :products, only: [:show, :new, :create, :edit, :update] do
    get '/changelog', action: :changelog
    get '/notes', to: 'notes#new', as: :new_notes
    resources :product_variants, only: [:create, :update]
    get '/variants/new', to: 'product_variants#new'
    get '/v/:id', to: 'product_variants#show', as: :variant
    get '/v/:id/edit', to: 'product_variants#edit', as: :edit_variant
    get '/v/:id/changelog', to: 'product_variants#changelog', as: :variant_changelog
    get '/v/:id/notes', to: 'notes#new', as: :new_variant_notes
  end

  resources :events, only: [:index]
  get '/events/past', to: 'events#past', as: :past_events
  get '/events/:year/:slug', to: 'events#show', as: :event
  resources :event_attendees, only: [:create, :destroy]
  resources :user_follows, only: [:create, :destroy]
  resources :user_blocks, only: [:create, :destroy]

  get '/search', to: "search#results"

  root "application#index"

  get '/sitemap', to: 'sitemap#show', as: :sitemap
  get '/feed.rss', to: 'feed#rss', as: :rss

  get '/changelog', to: 'static#changelog', constraints: lambda { |req| req.format == :html }
  get '/about', to: 'static#about', constraints: lambda { |req| req.format == :html }
  get '/privacy-policy', to: 'static#privacy_policy', constraints: lambda { |req| req.format == :html }
  get '/imprint', to: 'static#imprint', constraints: lambda { |req| req.format == :html }
  scope '/calculators', as: :calculators do
    root 'static#calculators', constraints: lambda { |req| req.format == :html }
    get '/resistors-for-amplifier-to-headphone-adapter', to: 'static#amp_to_headphone_calculator', constraints: lambda { |req| req.format == :html }
  end

  get '/', to: 'application#not_found', via: [:post, :put, :patch, :delete, :options]
  get '*url', to: 'application#not_found', via: :all, constraints: lambda { |req| !req.path.start_with?('/rails/') }
end
