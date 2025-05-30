class UserController < ApplicationController
  include ApplicationHelper
  include HistoryHelper
  include Bookmarks
  include NewsletterHelper

  before_action :authenticate_user!, except: [:newsletter_unsubscribe]
  before_action :set_menu

  def dashboard
    @page_title = I18n.t('dashboard')
    @active_dashboard_menu = :dashboard

    data = PaperTrail::Version.where(whodunnit: current_user.id)
                              .select(:item_id)
                              .distinct
                              .group('item_type', 'event')
                              .count
    @products_created = get_data(data, 'Product', 'create')
    @products_edited = get_data(data, 'Product', 'update')
    @brands_created = get_data(data, 'Brand', 'create')
    @brands_edited = get_data(data, 'Brand', 'update')

    @app_news = AppNews.where('created_at > ?', current_user.created_at)
                       .where.not(id: current_user.app_news_ids)
                       .order(:created_at)
                       .reverse
  end

  def bookmarks
    @page_title = Bookmark.model_name.human(count: 2)
    @active_dashboard_menu = :bookmarks

    all_bookmarks = current_user.bookmarks
                                .includes([product: [{ sub_categories: :category }, :brand]])
                                .includes([:product_variant])

    bookmarks = all_bookmarks

    if params[:category].present?
      sub_cat = SubCategory.friendly.find(params[:category])

      if sub_cat
        bookmarks = bookmarks.where({ product: { products_sub_categories: { sub_category_id: sub_cat.id } } })
                             .order(['brand.name', 'LOWER(product.name)'])
        @sub_category = sub_cat
      else
        bookmarks = bookmarks.order(['brand.name', 'LOWER(products.name)'])
      end
    else
      bookmarks = bookmarks.order(['brand.name', 'LOWER(products.name)'])
    end

    @bookmarks = bookmarks.map { |bookmark| BookmarkPresenter.new(bookmark) }
    @bookmark_lists = current_user.bookmark_lists

    @categories = get_grouped_sub_categories(bookmarks: all_bookmarks)
  end

  def contributions
    @page_title = I18n.t('headings.contributions')
    @active_dashboard_menu = :contributions

    products = Product.joins(:versions)
                      .distinct
                      .includes([:brand])
                      .select('products.*, versions.event')
                      .where(versions: { item_type: 'Product', whodunnit: current_user.id })
    product_variants = ProductVariant.joins(:versions)
                                     .distinct
                                     .includes([product: [:brand]])
                                     .select('product_variants.*, versions.event')
                                     .where(versions: { item_type: 'ProductVariant', whodunnit: current_user.id })
    @items = (products + product_variants)
             .sort_by { |possession| possession.display_name.downcase }
             .group_by(&:event)
    @brands = Brand.joins(:versions)
                   .distinct
                   .select('brands.*, versions.event')
                   .where(versions: { item_type: 'Brand', whodunnit: current_user.id })
                   .order(:name)
                   .group_by(&:event)
  end

  def history
    @page_title = I18n.t('headings.history')
    @active_dashboard_menu = :history
    @possessions = get_history_possessions(current_user.possessions)
  end

  def has
    if params[:brands].present?
      possessions = current_user.possessions
                                .includes([product: [:brand]])
                                .includes([product_variant: [product: [:brand]]])
                                .where(products: { brand_id: params[:brands] })

      brands = params[:brands].map do |brand_id|
        {
          id: brand_id.to_i,
          in_collection: possessions.any? do |possession|
            possession.product.brand.id == brand_id.to_i && possession.prev_owned == false
          end,
          previously_owned: possessions.any? do |possession|
            possession.product.brand.id == brand_id.to_i && possession.prev_owned == true
          end,
        }
      end
    end

    if params[:products].present?
      possessions = current_user.possessions
                                .includes([:product])
                                .where(product: params[:products], product_variant: nil)

      products = params[:products].map do |product_id|
        {
          id: product_id.to_i,
          in_collection: possessions.any? do |possession|
            possession.product.id == product_id.to_i && possession.prev_owned == false
          end,
          previously_owned: possessions.any? do |possession|
            possession.product.id == product_id.to_i && possession.prev_owned == true
          end,
        }
      end
    end

    if params[:product_variants].present?
      possessions = current_user.possessions
                                .includes([:product_variant])
                                .where(product_variant: params[:product_variants])

      product_variants = params[:product_variants].map do |product_variant_id|
        {
          id: product_variant_id.to_i,
          in_collection: possessions.any? do |possession|
            possession.product_variant.id == product_variant_id.to_i && possession.prev_owned == false
          end,
          previously_owned: possessions.any? do |possession|
            possession.product_variant.id == product_variant_id.to_i && possession.prev_owned == true
          end,
        }
      end
    end

    render json: {
      brands:,
      products:,
      product_variants:,
    }
  end

  def counts
    return unless user_signed_in?

    render json: {
      products: user_possessions_count(user: current_user, prev_owned: false),
      custom_products: user_custom_products_count(current_user),
      previous_products: user_possessions_count(user: current_user, prev_owned: true),
      setups: user_setups_count(current_user),
      bookmarks: user_bookmarks_count(current_user),
      notes: user_notes_count(current_user)
    }
  end

  def newsletter_unsubscribe
    if verify_unsubscribe_hash(params[:hash])
      user = User.find_by(email: params[:email])
      user.update(receives_newsletter: false)
      redirect_to root_path, notice: I18n.t('newsletter.messages.unsubscribed')
    else
      redirect_to root_path, alert: I18n.t('newsletter.messages.invalid_unsubscribe_link')
    end
  end

  private

  def get_data(data, model, event)
    data[[model, event]] || 0
  end

  def set_menu
    @active_menu = :dashboard
  end
end
