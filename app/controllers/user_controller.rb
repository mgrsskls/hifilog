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
  end

  def products
    add_breadcrumb I18n.t('headings.collection'), dashboard_products_path
    @page_title = I18n.t('headings.collection')
    @active_dashboard_menu = :products

    all = current_user.possessions
                      .where(prev_owned: false)
                      .includes([product: [{ sub_categories: :category }, :brand]])
                      .includes([:product_variant])
                      .includes([custom_product: [{ sub_categories: :category }]])
                      .includes([image_attachment: [:blob]])
                      .map do |possession|
                        if possession.custom_product_id
                          CustomProductPossessionPresenter.new(possession)
                        else
                          CurrentPossessionPresenter.new(possession)
                        end
                      end

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
    add_breadcrumb I18n.t('headings.bookmarks'), dashboard_bookmarks_path
    @page_title = I18n.t('headings.bookmarks')
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

  private

  def get_data(data, model, event)
    data[[model, event]] || 0
  end

  def set_breadcrumb
    @active_menu = :dashboard
    add_breadcrumb I18n.t('dashboard'), dashboard_root_path
  end
end
