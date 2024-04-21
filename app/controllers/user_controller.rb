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

    all_possessions = current_user.possessions.joins(:product)
                                  .includes([product: [{ sub_categories: :category }, :brand]])
                                  .includes([image_attachment: [:blob]])
                                  .includes([:setup_possession, :setup, :product_variant])
                                  .map { |possession| ItemPresenter.new(possession) }

    all_custom_products = current_user.possessions.joins(:custom_product)
                                      .includes([custom_product: [{ sub_categories: :category }]])
                                      .includes([:setup_possession, :setup])
                                      .map { |possession| CustomProductPresenter.new(possession) }

    all = (all_possessions + all_custom_products).sort_by { |p| p.short_name.downcase }

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
                     # rubocop:disable Style/BlockDelimiters
                     .map { |c|
                       [
                         c[0],
                         c[1].map { |sub_category|
                           # rubocop:enable Style/BlockDelimiters
                           {
                             name: sub_category.name,
                             friendly_id: sub_category.friendly_id,
                             path: dashboard_products_path(category: sub_category.friendly_id)
                           }
                         }
                       ]
                     }
    @reset_path = dashboard_products_path
  end

  def bookmarks
    add_breadcrumb I18n.t('headings.bookmarks'), dashboard_bookmarks_path
    @page_title = I18n.t('headings.bookmarks')
    @active_dashboard_menu = :bookmarks

    all_bookmarks = current_user.bookmarks.joins(:product)
                                .includes([product: [{ sub_categories: :category }, :brand]])
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
                               # rubocop:disable Style/BlockDelimiters
                               .map { |c|
                                 [
                                   c[0],
                                   c[1].map { |sub_category|
                                     # rubocop:enable Style/BlockDelimiters
                                     {
                                       name: sub_category.name,
                                       friendly_id: sub_category.friendly_id,
                                       path: dashboard_bookmarks_path(category: sub_category.friendly_id)
                                     }
                                   }
                                 ]
                               }
    @reset_path = dashboard_bookmarks_path
  end

  def prev_owneds
    add_breadcrumb I18n.t('headings.prev_owneds'), dashboard_prev_owneds_path
    @page_title = I18n.t('headings.prev_owneds')
    @active_dashboard_menu = :prev_owneds

    all_prev_owneds = current_user.prev_owneds
                                  .joins(:product)
                                  .includes([product: [{ sub_categories: :category }, :brand]])
                                  .order('LOWER(products.name)')
                                  .map { |prev_owned| PrevOwnedPresenter.new(prev_owned) }

    if params[:category].present?
      @sub_category = SubCategory.friendly.find(params[:category])
      @prev_owneds = all_prev_owneds.select { |prev_owned| @sub_category.products.include?(prev_owned.product) }

      if @prev_owneds.empty?
        @prev_owneds = all_prev_owneds
        @sub_category = nil
      end
    else
      @prev_owneds = all_prev_owneds
    end

    @categories = all_prev_owneds.map(&:product)
                                 .flat_map(&:sub_categories)
                                 .sort_by(&:name)
                                 .uniq
                                 .group_by(&:category)
                                 .sort_by { |category| category[0].order }
                                 # rubocop:disable Style/BlockDelimiters
                                 .map { |c|
                                   [
                                     c[0],
                                     c[1].map { |sub_category|
                                       # rubocop:enable Style/BlockDelimiters
                                       {
                                         name: sub_category.name,
                                         friendly_id: sub_category.friendly_id,
                                         path: dashboard_prev_owneds_path(category: sub_category.friendly_id)
                                       }
                                     }
                                   ]
                                 }
    @reset_path = dashboard_prev_owneds_path
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
    @items = (products + product_variants).sort_by(&:display_name).group_by(&:event)
    @brands = Brand.joins(:versions)
                   .distinct
                   .select('brands.*, versions.event')
                   .where(versions: { item_type: 'Brand', whodunnit: current_user.id })
                   .order(:name)
                   .group_by(&:event)
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
