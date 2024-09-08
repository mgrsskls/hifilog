class UserController < ApplicationController
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

  def products
    add_breadcrumb I18n.t('headings.collection'), dashboard_products_path
    @page_title = I18n.t('headings.collection')
    @active_dashboard_menu = :products

    all = map_possessions_to_presenter current_user.possessions
                                                   .where(prev_owned: false)
                                                   .includes([product: [{ sub_categories: :category }, :brand]])
                                                   .includes([
                                                               :product_variant,
                                                               :product_option,
                                                               :setup_possession,
                                                               :setup
                                                             ])
                                                   .includes([custom_product: [{ sub_categories: :category }]])
                                                   .includes([image_attachment: [:blob]])

    all = all.sort_by { |possession| possession.display_name.downcase }

    if params[:category].present?
      @sub_category = SubCategory.friendly.find(params[:category])
      @possessions = all.select do |possession|
        @sub_category.products.include?(possession.product) ||
          @sub_category.custom_products.include?(possession.custom_product)
      end
    else
      @possessions = all
    end

    @categories = all.flat_map(&:sub_categories)
                     .sort_by(&:name)
                     .uniq
                     .group_by(&:category)
                     .sort_by { |category| category[0].order }
                     .map do |c|
                       [
                         c[0],
                         c[1].map do |sub_category|
                           {
                             name: sub_category.name,
                             friendly_id: sub_category.friendly_id,
                             path: dashboard_products_path(category: sub_category.friendly_id)
                           }
                         end
                       ]
                     end
    @reset_path = dashboard_products_path
  end

  def bookmarks
    add_breadcrumb Bookmark.model_name.human(count: 2), dashboard_bookmarks_path
    @page_title = Bookmark.model_name.human(count: 2)
    @active_dashboard_menu = :bookmarks

    all_bookmarks = current_user.bookmarks.joins(:product)
                                .includes([product: [{ sub_categories: :category }, :brand]])
                                .includes([:product_variant])
                                .order('LOWER(products.name)')
                                .map { |bookmark| BookmarkPresenter.new(bookmark) }

    if params[:category].present?
      @sub_category = SubCategory.friendly.find(params[:category])
      @bookmarks = all_bookmarks.select { |bookmark| @sub_category.products.include?(bookmark.product) }

      if @bookmarks.empty?
        @bookmarks = all_bookmarks
        @sub_category = nil
      end
    else
      @bookmarks = all_bookmarks
    end

    @categories = all_bookmarks.map(&:product)
                               .flat_map(&:sub_categories)
                               .sort_by(&:name)
                               .uniq
                               .group_by(&:category)
                               .sort_by { |category| category[0].order }
                               .map do |c|
                                 [
                                   c[0],
                                   c[1].map do |sub_category|
                                     {
                                       name: sub_category.name,
                                       friendly_id: sub_category.friendly_id,
                                       path: dashboard_bookmarks_path(category: sub_category.friendly_id)
                                     }
                                   end
                                 ]
                               end
    @reset_path = dashboard_bookmarks_path
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

    from = current_user.possessions
                       .includes([:product_option])
                       .includes([image_attachment: [:blob]])
                       .where.not(period_from: nil)
                       .order(:period_from).map do |possession|
      presenter = if possession.custom_product_id
                    CustomProductPossessionPresenter.new(possession)
                  else
                    PossessionPresenter.new(possession)
                  end

      {
        date: presenter.period_from,
        type: :from,
        presenter:
      }
    end

    to = current_user.possessions
                     .includes([:product_option])
                     .includes([image_attachment: [:blob]])
                     .where.not(period_to: nil)
                     .order(:period_to).map do |possession|
      presenter = if possession.custom_product_id
                    CustomProductPossessionPresenter.new(possession)
                  else
                    PossessionPresenter.new(possession)
                  end

      {
        date: presenter.period_to,
        type: :to,
        presenter:
      }
    end

    @possessions = (from + to)
                   .sort_by { |possession| possession[:date] }
                   .group_by { |possession| possession[:date].year }
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
