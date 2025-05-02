class BrandsController < ApplicationController
  include ApplicationHelper

  before_action :set_paper_trail_whodunnit, only: [:create, :update]
  before_action :authenticate_user!, only: [:new, :create, :edit, :update, :changelog]
  before_action :set_breadcrumb, only: [:show, :new, :edit, :changelog, :products]
  before_action :set_active_menu
  before_action :find_brand, only: [:show]

  def index
    @page_title = Brand.model_name.human(count: 2)

    order = case params[:sort]
            when 'name_desc'
              'LOWER(name) DESC'
            when 'products_asc'
              'products_count ASC NULLS FIRST, LOWER(name)'
            when 'products_desc'
              'products_count DESC NULLS LAST, LOWER(name)'
            when 'country_asc'
              'country_code ASC, LOWER(name)'
            when 'country_desc'
              'country_code DESC, LOWER(name)'
            when 'added_asc'
              'created_at ASC, LOWER(name)'
            when 'added_desc'
              'created_at DESC, LOWER(name)'
            when 'updated_asc'
              'updated_at ASC, LOWER(name)'
            when 'updated_desc'
              'updated_at DESC, LOWER(name)'
            else
              'LOWER(name) ASC'
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

    brands = Brand.all

    if ABC.include?(params[:letter])
      brands = brands.where('left(lower(brands.name),1) = ?', params[:letter].downcase)
      @filter_applied = true
    end

    if STATUSES.include?(params[:status])
      brands = brands.where(discontinued: params[:status] == 'discontinued')
      @filter_applied = true
    end

    if @sub_category || @category
      brands = if @sub_category
                 brands.joins(:sub_categories)
                       .where(sub_categories: @sub_category)
               else
                 brands.where(sub_categories: { category_id: @category.id })
               end
      brands = brands.order(update_for_joined_tables(order))
    else
      brands = brands.order(order)
    end

    if params[:query].present?
      @brands_query = params[:query].strip
      if @brands_query.present?
        brands = brands.search_by_name(@brands_query)
        @filter_applied = true
      end
    end

    @brands = brands.includes(sub_categories: [:category]).page(params[:page])
  end

  def all
    respond_to do |format|
      format.json { render json: { brands: Brand.select([:name, :id]).order('LOWER(name)') } }
    end
  end

  def show
    @brand = Brand.includes(sub_categories: [:category]).friendly.find(params[:id])

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
    add_breadcrumb @brand.name, brand_path(@brand)
  end

  def products
    @brand = Brand.includes(sub_categories: [:category]).friendly.find(params[:brand_id])
    @sub_category = SubCategory.friendly.find(params[:sub_category]) if params[:sub_category].present?
    @category = @sub_category.category if @sub_category.present?

    @all_sub_categories_grouped ||= @brand.sub_categories.group_by(&:category).sort_by { |category| category[0].order }

    if @sub_category
      products = @sub_category.products.where(brand_id: @brand.id)
      add_breadcrumb @brand.name, brand_path(@brand)
      add_breadcrumb Product.model_name.human(count: 2), brand_products_path(brand_id: @brand.friendly_id)
      add_breadcrumb @sub_category.name
      @filter_applied = true
    else
      products = @brand.products
      add_breadcrumb @brand.name, brand_path(@brand)
      add_breadcrumb Product.model_name.human(count: 2)
    end

    if ABC.include?(params[:letter])
      products = products.where('left(lower(name),1) = :prefix', prefix: params[:letter].downcase)
      @filter_applied = true
    end

    if STATUSES.include?(params[:status])
      products = products.left_outer_joins(:product_variants)
                         .where(product_variants: { discontinued: params[:status] == 'discontinued' })
                         .or(
                           products.where(discontinued: params[:status] == 'discontinued')
                         )
      @filter_applied = true
    end

    if params[:diy_kit].present?
      products = products.left_outer_joins(:product_variants)
                         .where(product_variants: { diy_kit: params[:diy_kit] })
                         .or(
                           products.where(diy_kit: params[:diy_kit])
                         )
      @filter_applied = true
    end

    if params[:query].present?
      @brands_query = params[:query].strip
      if @brands_query.present?
        products = products.left_outer_joins(:product_variants)
                           .where('product_variants.name ILIKE ?', "%#{@brands_query}%")
                           .or(
                             products.where('products.name ILIKE ?', "%#{@brands_query}%")
                           )
        @filter_applied = true
      end
    end

    order = case params[:sort]
            when 'name_desc'
              'LOWER(products.name) DESC'
            when 'release_date_asc'
              'products.release_year ASC NULLS LAST,
               products.release_month ASC NULLS LAST,
               products.release_day ASC NULLS LAST,
               LOWER(products.name)'
            when 'release_date_desc'
              'products.release_year DESC NULLS LAST,
               products.release_month DESC NULLS LAST,
               products.release_day DESC NULLS LAST,
               LOWER(products.name)'
            else
              'LOWER(products.name) ASC'
            end

    @products = products.distinct
                        .select('products.*, LOWER(products.name)')
                        .includes([:sub_categories, :product_variants]).order(order).page(params[:page])
    @total_products_count = @brand.products.length

    @page_title = @brand.name
  end

  def new
    @page_title = I18n.t('brand.new.heading')

    add_breadcrumb I18n.t('brand.new.heading')

    @sub_category = SubCategory.friendly.find(params[:sub_category]) if params[:sub_category].present?
    @brand = @sub_category ? Brand.new(sub_category_ids: [@sub_category.id]) : Brand.new
    @categories = Category.includes([:sub_categories])
  end

  def edit
    @brand = Brand.friendly.find(params[:id])
    @page_title = I18n.t('edit_record', name: @brand.name)
    @categories = Category.includes([:sub_categories])

    add_breadcrumb @brand.name, brand_path(@brand)
    add_breadcrumb I18n.t('edit')
  end

  def create
    @brand = Brand.new(brand_params)

    if @brand.save
      redirect_to brand_path(@brand)
    else
      @categories = Category.includes([:sub_categories])
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
      @categories = Category.includes([:sub_categories])
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
    params.expect(
      brand: [:name,
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
              { sub_category_ids: [] }],
    )
  end
end
