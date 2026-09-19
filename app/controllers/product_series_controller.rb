# frozen_string_literal: true

# Product series pages: /brands/:brand_id/series/:id. See docs/product-series.md.
#
# "series" is uncountable in Rails, so the route helpers are brand_series_index_path (the JSON
# list the product form reads) and brand_series_path (one series).
class ProductSeriesController < ApplicationController
  include FilterParamsBuilder

  # Products of the brand per page in the product list of the edit page. Also the upper limit of
  # product changes per submit.
  PRODUCTS_PER_PAGE = 50
  MAX_ASSIGNMENTS_PER_SUBMIT = 100

  before_action :set_paper_trail_whodunnit, only: [:create, :update]
  before_action :authenticate_user!, only: [:new, :create, :edit, :update]
  before_action :set_noindex_meta_robots, only: [:new, :edit, :create, :update, :changelog]
  before_action :set_active_menu
  before_action :load_brand
  before_action :load_series, only: [:show, :edit, :update, :changelog]
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

  # The edit page has the name and the description of the series, and the products of the brand
  # with a checkbox each (see #load_brand_products). One submit saves both.
  def edit
    load_brand_products
    page_title(I18n.t('edit_record', name: @series.display_name))
  end

  def create
    @series = @brand.product_series.new(series_params)

    if save_series(@series)
      if params[:assign_products].present?
        redirect_to edit_brand_series_path(brand_id: @brand.friendly_id, id: @series.friendly_id, anchor: 'products')
      else
        redirect_to @series.path
      end
    else
      page_title(I18n.t('product_series.new.heading', brand: @brand.display_name))
      render :new, status: :unprocessable_content
    end
  end

  # Saves the series and the product checkboxes of the submitted page (ProductSeriesAssignment).
  # A product that can not change leaves the others alone: the page reports it and the rest is
  # saved. Only invalid attributes of the series stop the whole submit.
  def update
    changes = assignment_changes

    if changes.size > MAX_ASSIGNMENTS_PER_SUBMIT
      @series.assign_attributes(series_params)
      @series.errors.add(:base, I18n.t('product_series.assign.too_many', max: MAX_ASSIGNMENTS_PER_SUBMIT))
      return render_edit_with_errors
    end

    result = ProductSeriesAssignment.new(series: @series, attributes: series_params, changes:,
                                         selected_ids: @selected_ids).call
    return render_edit_with_errors unless result.series_saved?

    report(result)
    redirect_to @series.path
  end

  def changelog
    @versions = filter_versions(@series.versions)
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

  def contributors
    User.find_by_sql([<<~SQL.squish, @series.id])
      SELECT DISTINCT users.id, users.user_name, users.profile_visibility
      FROM users
      JOIN versions ON users.id = CAST(versions.whodunnit AS integer)
      WHERE versions.item_id = ? AND versions.item_type = 'ProductSeries'
    SQL
  end

  # The products of the brand for the checkbox list of the edit page, by name, 50 per page, with
  # an optional search on name and model no. The list shows the brand's products only, so the
  # query uses index_products_on_brand_id_and_product_series_id's leading column.
  def load_brand_products
    @query = params[:query].to_s.strip.presence
    products = @brand.products.reorder(Arel.sql('LOWER(products.name) ASC, products.id ASC'))
                     .includes(:product_series)
    if @query
      products = products.where('products.name ILIKE :q OR products.model_no ILIKE :q',
                                q: "%#{Product.sanitize_sql_like(@query)}%")
    end
    @products = products.page(params[:page]).per(PRODUCTS_PER_PAGE)
  end

  # product_ids: the products on the submitted page. selected_ids: the checked ones. Only the
  # products on the page change, so a submit never touches products the user did not see.
  # Products of other brands are ignored.
  def assignment_changes
    @selected_ids = Array(params[:selected_ids]).to_set(&:to_i)
    on_page = Array(params[:product_ids]).map(&:to_i).uniq
    return [] if on_page.empty?

    @brand.products.where(id: on_page).to_a.reject do |product|
      @selected_ids.include?(product.id) == (product.product_series_id == @series.id)
    end
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

  # The number of changed products, or a plain confirmation when the submit only changed the
  # series. No notice when nothing was changed and the alert says why: that is not a success.
  def notice_for(result)
    return I18n.t('product_series.assign.saved', count: result.changed.size) if result.changed.any?

    I18n.t('product_series.assign.series_saved') if result.skipped.empty?
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

  # The checkboxes keep what the user checked (@selected_ids), not the saved state.
  def render_edit_with_errors
    load_brand_products
    page_title(I18n.t('edit_record', name: @series.display_name))
    render :edit, status: :unprocessable_content
  end
end
