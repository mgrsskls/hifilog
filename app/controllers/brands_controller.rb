class BrandsController < ApplicationController
  include ApplicationHelper

  STATUSES = %w[discontinued continued].freeze

  before_action :set_paper_trail_whodunnit, only: [:create, :update]
  before_action :authenticate_user!, only: [:new, :create, :edit, :update, :changelog]
  before_action :set_breadcrumb, only: [:show, :new, :edit, :changelog]
  before_action :set_active_menu
  before_action :find_brand, only: [:show]

  def index
    @page_title = Brand.model_name.human(count: 2)

    order = 'LOWER(name) ASC'
    if params[:sort].present?
      order = 'LOWER(name) ASC' if params[:sort] == 'name_asc'
      order = 'LOWER(name) DESC' if params[:sort] == 'name_desc'
      order = 'products_count ASC NULLS FIRST, LOWER(name)' if params[:sort] == 'products_asc'
      order = 'products_count DESC NULLS LAST, LOWER(name)' if params[:sort] == 'products_desc'
      order = 'country_code ASC, LOWER(name)' if params[:sort] == 'country_asc'
      order = 'country_code DESC, LOWER(name)' if params[:sort] == 'country_desc'
      order = 'created_at ASC, LOWER(name)' if params[:sort] == 'added_asc'
      order = 'created_at DESC, LOWER(name)' if params[:sort] == 'added_desc'
      order = 'updated_at ASC, LOWER(name)' if params[:sort] == 'updated_asc'
      order = 'updated_at DESC, LOWER(name)' if params[:sort] == 'updated_desc'
    end

    @sub_category = SubCategory.friendly.find(params[:sub_category]) if params[:sub_category].present?
    if @sub_category
      @category = Category.find(@sub_category.category_id)
      add_breadcrumb Brand.model_name.human(count: 2), proc { :brands }
      add_breadcrumb @category.name, brands_path(category: @category.friendly_id)
      add_breadcrumb @sub_category.name
    elsif params[:category].present?
      add_breadcrumb Brand.model_name.human(count: 2), proc { :brands }
      @category = Category.friendly.find(params[:category])
      add_breadcrumb @category.name
    else
      add_breadcrumb Brand.model_name.human(count: 2)
    end

    if params[:letter].present? &&
       ABC.include?(params[:letter]) &&
       @sub_category &&
       params[:status].present?
      discontinued = STATUSES.include?(params[:status]) && params[:status] == 'discontinued'
      brands = Brand.joins(:sub_categories)
                    .where(sub_categories: @sub_category, discontinued:)
                    .where('left(lower(brands.name),1) = ?', params[:letter].downcase)
                    .order(update_for_joined_tables(order))
    elsif params[:letter].present? &&
          ABC.include?(params[:letter]) &&
          @category &&
          params[:status].present?
      discontinued = STATUSES.include?(params[:status]) && params[:status] == 'discontinued'
      brands = Brand.joins(:sub_categories)
                    .where(sub_categories: { category_id: @category.id }, discontinued:)
                    .where('left(lower(brands.name),1) = ?', params[:letter].downcase)
                    .order(update_for_joined_tables(order))
    elsif params[:letter].present? && ABC.include?(params[:letter]) && @sub_category
      @category = Category.find(@sub_category.category_id)
      brands = Brand.joins(:sub_categories)
                    .where(sub_categories: @sub_category)
                    .where('left(lower(brands.name),1) = ?', params[:letter].downcase)
                    .order(update_for_joined_tables(order))
    elsif params[:letter].present? && ABC.include?(params[:letter]) && @category
      brands = Brand.joins(:sub_categories)
                    .where(sub_categories: { category_id: @category.id })
                    .where('left(lower(brands.name),1) = ?', params[:letter].downcase)
                    .order(update_for_joined_tables(order))
    elsif params[:letter].present? && ABC.include?(params[:letter]) && params[:status].present?
      brands = Brand.where('left(lower(brands.name),1) = :prefix', prefix: params[:letter].downcase)
                    .where(discontinued: STATUSES.include?(params[:status]) ? params[:status] == 'discontinued' : nil)
                    .order(order)
    elsif @sub_category && params[:status].present?
      discontinued = STATUSES.include?(params[:status]) && params[:status] == 'discontinued'
      brands = Brand.joins(:sub_categories)
                    .where(sub_categories: @sub_category, discontinued:)
                    .order(update_for_joined_tables(order))
    elsif @category && params[:status].present?
      discontinued = STATUSES.include?(params[:status]) && params[:status] == 'discontinued'
      brands = Brand.joins(:sub_categories)
                    .where(sub_categories: { category_id: @category.id }, discontinued:)
                    .order(update_for_joined_tables(order))
    elsif params[:letter].present? && ABC.include?(params[:letter])
      brands = Brand.where('left(lower(name),1) = :prefix', prefix: params[:letter].downcase)
                    .order(order)
    elsif @sub_category
      brands = Brand.joins(:sub_categories)
                    .where(sub_categories: @sub_category)
                    .order(update_for_joined_tables(order))
    elsif @category.present?
      brands = Brand.joins(:sub_categories)
                    .where(sub_categories: { category_id: @category.id })
                    .order(update_for_joined_tables(order))
    elsif params[:status].present?
      brands = Brand.where(discontinued: STATUSES.include?(params[:status]) ? params[:status] == 'discontinued' : nil)
                    .order(order)
    else
      brands = Brand.order(order)
    end

    @brands_query = params[:query].strip if params[:query].present?
    brands = brands.search_by_name_and_description(@brands_query) if @brands_query.present?

    @brands = brands.includes(sub_categories: [:category]).page(params[:page])
  end

  def all
    respond_to do |format|
      format.json { render json: { brands: Brand.select([:name, :id]).order('LOWER(name)') } }
    end
  end

  def show
    @brand = Brand.includes(sub_categories: [:category]).friendly.find(params[:id])
    @sub_category = SubCategory.friendly.find(params[:sub_category]) if params[:sub_category].present?
    @category = @sub_category.category if @sub_category.present?

    if @sub_category
      products = @sub_category.products.where(brand_id: @brand.id)
      add_breadcrumb @brand.name, proc { :brand }
      add_breadcrumb @sub_category.name
    else
      products = @brand.products
      add_breadcrumb @brand.name
    end

    if params[:status].present? && STATUSES.include?(params[:status])
      products = products.where(
        discontinued: STATUSES.include?(params[:status]) ? params[:status] == 'discontinued' : nil
      )
    end

    @brands_query = params[:query].strip if params[:query].present?
    products = products.search_by_name_and_description(@brands_query) if @brands_query.present?

    if params[:letter].present? && ABC.include?(params[:letter])
      products = products.where('left(lower(name),1) = :prefix', prefix: params[:letter].downcase)
    end

    order = 'LOWER(name) ASC'
    if params[:sort].present?
      order = 'LOWER(name) ASC' if params[:sort] == 'name_asc'
      order = 'LOWER(name) DESC' if params[:sort] == 'name_desc'
      if params[:sort] == 'release_date_asc'
        order = 'release_year ASC NULLS LAST, release_month ASC NULLS LAST, release_day ASC NULLS LAST, LOWER(name)'
      end
      if params[:sort] == 'release_date_desc'
        order = 'release_year DESC NULLS LAST, release_month DESC NULLS LAST, release_day DESC NULLS LAST, LOWER(name)'
      end
    end
    @products = products.includes([:sub_categories]).order(order).page(params[:page])
    @total_products_count = @brand.products.count

    @contributors = User.find_by_sql(["
      SELECT DISTINCT
        users.id, users.user_name, users.profile_visibility,
        versions.item_type, versions.item_id FROM users
      JOIN versions
      ON users.id = CAST(versions.whodunnit AS integer)
      WHERE versions.item_id = ? AND versions.item_type = 'Brand'
    ", @brand.id])

    @all_sub_categories_grouped ||= @brand.sub_categories.group_by(&:category).sort_by { |category| category[0].order }

    @page_title = @brand.name
  end

  def new
    @page_title = I18n.t('brand.new.heading')

    add_breadcrumb I18n.t('brand.new.heading')

    @sub_category = SubCategory.friendly.find(params[:sub_category]) if params[:sub_category].present?
    @brand = @sub_category ? Brand.new(sub_category_ids: [@sub_category.id]) : Brand.new
    @categories = Category.includes([:sub_categories]).order(:order)
  end

  def edit
    @brand = Brand.friendly.find(params[:id])
    @page_title = I18n.t('edit_record', name: @brand.name)
    @categories = Category.includes([:sub_categories]).order(:order)

    add_breadcrumb @brand.name, brand_path(@brand)
    add_breadcrumb I18n.t('edit')
  end

  def create
    @brand = Brand.new(brand_params)

    if @brand.save
      redirect_to brand_path(@brand)
    else
      @categories = Category.includes([:sub_categories]).order(:order)
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @brand = Brand.friendly.find(params[:id])
    is_discontinued = @brand.discontinued

    old_name = @brand.name
    @brand.slug = nil if old_name != brand_params[:name]

    if @brand.update(brand_params)
      if is_discontinued == false && @brand.discontinued == true
        @brand.products.each do |product|
          product.update(discontinued: true)
        end
      end

      redirect_to brand_path(@brand)
    else
      @categories = Category.includes([:sub_categories]).order(:order)
      render :edit, status: :unprocessable_entity
    end
  end

  def changelog
    @brand = Brand.friendly.find(params[:brand_id])
    @versions = @brand.versions.select do |v|
      log = get_changelog(v.object_changes)
      log.length > 1 || (log.length == 1 && log['slug'].nil?)
    end

    add_breadcrumb @brand.name, brand_path(@brand)
    add_breadcrumb I18n.t('headings.changelog')
  end

  private

  def find_brand
    @brand = Brand.friendly.find(params[:id])

    return unless request.path != brand_path(@brand)

    # If an old id or a numeric id was used to find the record, then
    # the request path will not match the brand_path, and we should do
    # a 301 redirect that uses the current friendly id.
    redirect_to URI.parse(brand_path(id: @brand.friendly_id)).path, status: :moved_permanently
  end

  def update_for_joined_tables(order)
    order
      .sub('LOWER(name)', 'brands.name')
      .sub('products_count', 'brands.products_count')
      .sub('country_code', 'brands.country_code')
      .sub('created_at', 'brands.created_at')
      .sub('updated_at', 'brands.updated_at')
  end

  def set_active_menu
    @active_menu = :brands
  end

  def set_breadcrumb
    add_breadcrumb Brand.model_name.human(count: 2), brands_path
  end

  def brand_params
    params.require(:brand).permit(
      :name,
      :discontinued,
      :full_name,
      :website,
      :country_code,
      :founded_day,
      :founded_month,
      :founded_year,
      :discontinued_day,
      :discontinued_month,
      :discontinued_year,
      :description,
      :comment,
      sub_category_ids: [],
    )
  end
end
