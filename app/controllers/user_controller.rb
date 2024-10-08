class UserController < ApplicationController
  include ApplicationHelper
  include HistoryHelper
  include Bookmarks

  before_action :authenticate_user!
  before_action :set_breadcrumb

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
    add_breadcrumb Bookmark.model_name.human(count: 2), dashboard_bookmarks_path
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
    add_breadcrumb I18n.t('headings.contributions'), dashboard_contributions_path
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
    add_breadcrumb I18n.t('headings.history'), dashboard_history_path
    @page_title = I18n.t('headings.history')
    @active_dashboard_menu = :history
    @possessions = get_history_possessions(current_user.possessions)
  end

  def statistics
    add_breadcrumb I18n.t('headings.statistics'), dashboard_statistics_path
    @page_title = I18n.t('headings.statistics')
    @active_dashboard_menu = :statistics

    products_added_removed = current_user.possessions.where.not(period_from: nil).or(
      current_user.possessions.where.not(period_to: nil)
    )

    years_added_removed = []
    years_added = []
    years_removed = []

    products_added_removed.each do |product|
      if product.period_from.present?
        years_added_removed << product.period_from.year
        years_added << product.period_from.year
      end
      if product.period_to.present?
        years_added_removed << product.period_to.year
        years_removed << product.period_to.year
      end
    end

    products_added_removed_per_year = years_added_removed.uniq.sort.map do |year|
      {
        year:,
        possessions: {
          from: products_added_removed.select do |possession|
            possession.period_from.present? && possession.period_from.year == year
          end,
          to: products_added_removed.select do |possession|
            possession.period_to.present? && possession.period_to.year == year
          end,
        }
      }
    end

    products_added_per_year = years_added.uniq.sort.map do |year|
      {
        year:,
        possessions: {
          from: products_added_removed.select do |possession|
            possession.period_from.present? && possession.period_from.year == year
          end,
        }
      }
    end

    products_removed_per_year = years_removed.uniq.sort.map do |year|
      {
        year:,
        possessions: {
          to: products_added_removed.select do |possession|
            possession.period_to.present? && possession.period_to.year == year
          end,
        }
      }
    end

    @products_added_removed_per_year = products_added_removed_per_year
    @products_added_per_year = products_added_per_year
    @products_removed_per_year = products_removed_per_year
    @current_products_per_brand = get_products_per_brand
    @all_products_per_brand = get_products_per_brand(all: true)
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

  private

  def get_products_per_brand(all: false)
    products_per_brand = current_user.possessions
                                     .includes([:custom_product])
                                     .includes([product: [:brand]])

    products_per_brand = products_per_brand.where.not(prev_owned: true) unless all

    products_per_brand = products_per_brand.map do |possession|
      if possession.custom_product
        {
          brand_name: CustomProductPresenter.new(possession.custom_product).brand_name,
          possession:
        }
      else
        {
          brand_name: possession.product.brand.name,
          possession:
        }
      end
    end

    products_per_brand = products_per_brand.group_by do |possession|
      possession[:brand_name]
    end

    products_per_brand.sort_by do |brand|
      [-brand[1].size, brand[0].downcase]
    end
  end

  def get_data(data, model, event)
    data[[model, event]] || 0
  end

  def set_breadcrumb
    @active_menu = :dashboard
    add_breadcrumb I18n.t('dashboard'), dashboard_root_path
  end
end
