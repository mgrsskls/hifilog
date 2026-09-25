# frozen_string_literal: true

# Product series pages: /brands/:brand_id/series/:id. See docs/product-series.md.
#
# "series" is uncountable in Rails, so the route helpers are brand_series_index_path (the JSON
# list the product form reads) and brand_series_path (one series).
class ProductSeriesController < ApplicationController
  include FilterParamsBuilder

  # The dialog of the series page shows all products of the brand, so one submit can change many
  # of them. The limit keeps one submit small enough for one request.
  MAX_ASSIGNMENTS_PER_SUBMIT = 500

  # All products of the brand for the dialog, the products of this series first, then by name.
  # index_products_on_brand_id_and_product_series_id gives the rows of the brand; the sort is over
  # these rows only, not over the catalog.
  ASSIGNABLE_PRODUCTS_ORDER_SQL = 'COALESCE(products.product_series_id = %<series_id>d, FALSE) DESC, ' \
                                  'LOWER(products.name) ASC, products.id ASC'

  before_action :set_paper_trail_whodunnit, only: [:create, :update, :assign_products]
  before_action :authenticate_user!, only: [:new, :create, :edit, :update, :assignable_products,
                                            :assign_products]
  before_action :set_noindex_meta_robots, only: [:new, :edit, :create, :update, :changelog]
  before_action :set_active_menu
  before_action :load_brand
  before_action :load_series, only: [:show, :edit, :update, :changelog, :assignable_products,
                                     :assign_products]
  before_action :redirect_to_canonical_series_path, only: [:show]

  # The series of a brand, for the series field of the product form. Few rows per brand, so the
  # form loads all of them and needs no search on the server.
  def index
    respond_to do |format|
      format.json do
        render json: { series: @brand.product_series.order(:name).select(:id, :name, :slug) }
      end
      format.html { redirect_to brand_path(id: @brand.friendly_id), status: :moved_permanently }
    end
  end

  def show
    @filter_applied = active_filters.except(:sort)
    filter_service = ProductFilterService.new(
      filters: active_filters.reverse_merge(sort: 'release_date_asc'),
      brands: [@brand],
      series: @series
    )
    products = filter_service.filter.products.includes(:brand)
    total_count = filter_service.total_count

    @products = PrecomputedTotalCount.attach(products.page(params[:page]), total_count)
    @products = PrecomputedTotalCount.attach(products.page(1), total_count) if @products.out_of_range?
    @products = ProductItem.preload_list_possession_images(@products)
    @products = ProductItem.preload_sub_category_names(@products)

    @products_query = params.dig(:products, :query)&.strip
    @contributors = contributors

    @meta_robots = 'noindex, follow' if @filter_applied.present? || @series.products_count.zero?
    @canonical_url = canonical_url
    page_title(@series.display_label, @series.meta_desc)
  end

  def new
    @series = @brand.product_series.new
    page_title(I18n.t('product_series.new.heading', brand: @brand.display_name))
  end

  # The name and the description of the series. The products are assigned on the series page
  # (#assign_products).
  def edit
    page_title(I18n.t('edit_record', name: @series.display_name))
  end

  # The product rows of the dialog of the series page. No layout: the dialog puts the answer in
  # its list.
  def assignable_products
    render partial: 'product_series/assignable_products', locals: assignable_products_locals,
           layout: false
  end

  def create
    @series = @brand.product_series.new(series_params)

    if save_series(@series)
      if params[:assign_products].present?
        # The anchor opens the dialog (entity_picker_dialog.js).
        redirect_to "#{@series.path}#assign-products"
      else
        redirect_to @series.path
      end
    else
      page_title(I18n.t('product_series.new.heading', brand: @brand.display_name))
      render :new, status: :unprocessable_content
    end
  end

  def update
    @series.assign_attributes(series_params)

    if save_series(@series)
      redirect_to @series.path, notice: I18n.t('product_series.assign.series_saved')
    else
      page_title(I18n.t('edit_record', name: @series.display_name))
      render :edit, status: :unprocessable_content
    end
  end

  # Saves the product checkboxes of the dialog of the series page (ProductSeriesAssignment). A
  # product that can not change leaves the others alone: the page reports it and the rest is
  # saved. The name and the description of the series do not change here.
  def assign_products
    changes = assignment_changes

    if changes.size > MAX_ASSIGNMENTS_PER_SUBMIT
      flash[:alert] = I18n.t('product_series.assign.too_many', max: MAX_ASSIGNMENTS_PER_SUBMIT)
    else
      report(ProductSeriesAssignment.new(series: @series, changes:, selected_ids: @selected_ids).call)
    end
    redirect_to @series.path
  end

  def changelog
    @versions = filter_versions(@series.changelog_versions)
    @changelog_products = changelog_products
    page_title("#{I18n.t('headings.changelog')} — #{@series.display_name}")
  end

  private

  def set_noindex_meta_robots
    @meta_robots = 'noindex, follow'
  end

  def set_active_menu
    @active_menu = :brands
  end

  def load_brand
    @brand = Brand.friendly.find(params[:brand_id])
  end

  def load_series
    @series = @brand.product_series.friendly.find(params[:series_id] || params[:id])
  end

  # An old brand slug or an old series slug answers with a 301 to the current URL, as FriendlyFinder
  # does for brands and products.
  def redirect_to_canonical_series_path
    return unless request.get?
    return if params[:brand_id] == @brand.friendly_id && params[:id] == @series.friendly_id

    redirect_to brand_series_path(brand_id: @brand.friendly_id, id: @series.friendly_id,
                                  **request.query_parameters.symbolize_keys),
                status: :moved_permanently
  end

  def series_params
    params.expect(product_series: [:name, :description, :comment])
  end

  # The uniqueness validation is not atomic. Two submits of the same name can still reach the
  # unique index; then the second one shows the validation error instead of a 500.
  def save_series(series)
    series.save
  rescue ActiveRecord::RecordNotUnique
    series.errors.add(:name, :taken)
    false
  end

  def allowed_filter_params
    params.permit(:sort, products: [:status, :query, :diy_kit])
  end

  def active_filters
    @active_filters ||= build_filters(allowed_filter_params).merge(build_product_filters(allowed_filter_params))
  end

  def canonical_url
    opts = @products.current_page > 1 ? { page: @products.current_page } : {}
    brand_series_url(brand_id: @brand.friendly_id, id: @series.friendly_id, **opts)
  end

  # The users who edited the series, and the users who added products to it or removed products
  # from it.
  def contributors
    User.find_by_sql([<<~SQL.squish, { series_id: @series.id }])
      SELECT DISTINCT users.id, users.user_name, users.profile_visibility
      FROM users
      JOIN versions ON users.id = CAST(versions.whodunnit AS integer)
      WHERE (versions.item_id = :series_id AND versions.item_type = 'ProductSeries')
         OR versions.product_series_ids @> ARRAY[:series_id]::bigint[]
    SQL
  end

  # { product id => product } for the product versions of the changelog, in one query. A deleted
  # product, or a product converted into a variant, is not in it; the changelog then takes the name
  # from the version.
  def changelog_products
    ids = @versions.select { |version| version.item_type == 'Product' }.map(&:item_id).uniq
    Product.where(id: ids).includes(:brand).index_by(&:id)
  end

  # All products of the brand, with only the columns a row shows. The series of the brand are a
  # hash, so a row of another series needs no query of its own.
  def assignable_products_locals
    { series: @series,
      products: @brand.products
                      .select(:id, :name, :model_no, :product_series_id)
                      .reorder(Arel.sql(format(ASSIGNABLE_PRODUCTS_ORDER_SQL, series_id: @series.id)))
                      .to_a,
      series_by_id: @brand.product_series.index_by(&:id) }
  end

  # The products whose series the submit changes. product_ids are the rows the dialog had loaded,
  # selected_ids the checked ones among them; products_loaded says that the dialog had loaded its
  # list, so an unchecked row leaves the series. Without it the submit changes no product: the user
  # did not open the dialog. Only the loaded rows change, so a product that joined the series
  # after the dialog loaded stays in it. Products of other brands are not in the queries.
  def assignment_changes
    @selected_ids = id_param_set(:selected_ids)
    @listed_ids = id_param_set(:product_ids)
    @products_loaded = params[:products_loaded] == '1'
    return [] unless @products_loaded && @listed_ids.any?

    (products_to_join + products_to_leave).sort_by { |product| [product.name.downcase, product.id] }
  end

  # IS DISTINCT FROM, because "product_series_id != id" is unknown for a product without a series.
  def products_to_join
    ids = @selected_ids & @listed_ids
    return [] if ids.empty?

    @brand.products.where(id: ids.to_a)
          .where('products.product_series_id IS DISTINCT FROM ?', @series.id).to_a
  end

  def products_to_leave
    ids = @listed_ids - @selected_ids
    return [] if ids.empty?

    @brand.products.where(id: ids.to_a, product_series_id: @series.id).to_a
  end

  def id_param_set(key)
    Array(params[key]).filter_map { |id| id.to_s.presence&.to_i }.to_set
  end

  # What the submit did: the number of changed products, and one line per product that did not
  # change. A line for a name clash names the other product, links to it and says how to solve it.
  def report(result)
    # Assigned only when there is one: flash[:notice] = nil still makes a key, and the layout
    # then shows an empty box.
    notice = notice_for(result)
    flash[:notice] = notice if notice
    return if result.skipped.empty?

    # The flash is sanitized when it is shown (FlashHelper), so the link survives.
    # rubocop:disable Rails/ActionControllerFlashBeforeRender
    flash[:alert] = result.skipped.map { |entry| skipped_message(entry) }.join(' ')
    # rubocop:enable Rails/ActionControllerFlashBeforeRender
  end

  # The number of changed products, or a plain note when nothing changed. No notice when nothing
  # was changed and the alert says why: that is not a success.
  def notice_for(result)
    return I18n.t('product_series.assign.saved', count: result.changed.size) if result.changed.any?

    I18n.t('product_series.assign.unchanged') if result.skipped.empty?
  end

  def skipped_message(entry)
    if entry.conflict.nil?
      return I18n.t('product_series.assign.skipped_invalid_html', name: entry.product.name,
                                                                  errors: entry.errors)
    end

    link = helpers.link_to(entry.conflict.display_name, product_path(id: entry.conflict.friendly_id))
    # "scope" is a reserved I18n option, so the placeholder is "where".
    I18n.t('product_series.assign.skipped_conflict_html', name: entry.product.name, link:,
                                                          where: conflict_where(entry.conflict))
  end

  # Where the other product sits: in a series of its own, or in no series.
  def conflict_where(conflict)
    series = conflict.product_series
    return I18n.t('product_series.assign.where_none') if series.nil?

    I18n.t('product_series.assign.where_series', series: series.label)
  end
end
