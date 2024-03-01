class BrandsController < ApplicationController
  include ApplicationHelper
  include BrandHelper

  STATUSES = %w[discontinued continued].freeze

  before_action :set_paper_trail_whodunnit, only: [:create, :update]
  before_action :authenticate_user!, only: [:new, :create, :edit, :update, :changelog]
  before_action :set_breadcrumb, only: [:show, :new, :edit, :changelog]
  before_action :set_active_menu
  before_action :find_brand, only: [:show]

  def index
    @page_title = I18n.t('headings.brands')

    if (params[:letter].present? && ABC.include?(params[:letter])) ||
       params[:category].present? ||
       params[:sub_category].present? ||
       params[:status].present?
      add_breadcrumb I18n.t('headings.brands'), proc { :brands }
    else
      add_breadcrumb I18n.t('headings.brands')
    end

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
    else
      order = 'LOWER(name) ASC'
    end

    @sub_category = SubCategory.friendly.find(params[:sub_category]) if params[:sub_category].present?
    if @sub_category
      @category = Category.find(@sub_category.category_id)
    elsif params[:category].present?
      @category = Category.friendly.find(params[:category])
    end

    if params[:letter].present? &&
       ABC.include?(params[:letter]) &&
       @sub_category &&
       params[:status].present?
      add_breadcrumb params[:letter].upcase, brands_path(letter: params[:letter])
      add_breadcrumb @category.name, brands_path(letter: params[:letter], category: @category.friendly_id)
      add_breadcrumb @sub_category.name, brands_path(
        letter: params[:letter],
        sub_category: @sub_category.friendly_id,
      )
      add_breadcrumb I18n.t(params[:status])
      discontinued = STATUSES.include?(params[:status]) && params[:status] == 'discontinued'
      brands = Kaminari.paginate_array(Brand.find_by_sql(["
        SELECT * FROM (
          SELECT brands.*
          FROM brands
          LEFT JOIN products ON products.brand_id = brands.id
          LEFT JOIN products_sub_categories ON products_sub_categories.product_id = products.id
          LEFT JOIN sub_categories ON sub_categories.id = products_sub_categories.sub_category_id
          WHERE sub_categories.id = ?
          UNION
          SELECT DISTINCT brands.*
          FROM brands
          INNER JOIN brands_sub_categories
          ON brands_sub_categories.brand_id = brands.id
          AND brands_sub_categories.sub_category_id = ?
          ) AS brand WHERE left(lower(brand.name),1) = ? AND brand.discontinued = ? ORDER BY
      " + order, @sub_category.id, @sub_category.id, params[:letter].downcase, discontinued]))
    elsif params[:letter].present? &&
          ABC.include?(params[:letter]) &&
          @category &&
          params[:status].present?
      add_breadcrumb params[:letter].upcase, brands_path(letter: params[:letter])
      add_breadcrumb @category.name, brands_path(letter: params[:letter], category: @category.friendly_id)
      add_breadcrumb I18n.t(params[:status])
      discontinued = STATUSES.include?(params[:status]) && params[:status] == 'discontinued'
      brands = Kaminari.paginate_array(Brand.find_by_sql(["
        SELECT * FROM (
          SELECT brands.*
          FROM brands
          LEFT JOIN products ON products.brand_id = brands.id
          LEFT JOIN products_sub_categories ON products_sub_categories.product_id = products.id
          LEFT JOIN sub_categories ON sub_categories.id = products_sub_categories.sub_category_id
          WHERE sub_categories.category_id = ?
          UNION
          SELECT DISTINCT brands.*
          FROM brands
          INNER JOIN brands_sub_categories
          ON brands_sub_categories.brand_id = brands.id
          LEFT JOIN categories ON categories.id = brands_sub_categories.sub_category_id
          WHERE categories.id = ?
        ) AS brand WHERE left(lower(brand.name),1) = ? AND brand.discontinued = ? ORDER BY
      " + order, @category.id, @category.id, params[:letter].downcase, discontinued]))
    elsif params[:letter].present? && ABC.include?(params[:letter]) && @sub_category
      @category = Category.find(@sub_category.category_id)
      add_breadcrumb params[:letter].upcase, brands_path(letter: params[:letter])
      add_breadcrumb @category.name, brands_path(letter: params[:letter], category: @category.friendly_id)
      add_breadcrumb @sub_category.name
      brands = Kaminari.paginate_array(Brand.find_by_sql(["
        SELECT * FROM (
          SELECT brands.*
          FROM brands
          LEFT JOIN products ON products.brand_id = brands.id
          LEFT JOIN products_sub_categories ON products_sub_categories.product_id = products.id
          LEFT JOIN sub_categories ON sub_categories.id = products_sub_categories.sub_category_id
          WHERE sub_categories.id = ?
          UNION
          SELECT DISTINCT brands.*
          FROM brands
          INNER JOIN brands_sub_categories
          ON brands_sub_categories.brand_id = brands.id
          AND brands_sub_categories.sub_category_id = ?
          ) AS brand WHERE left(lower(brand.name),1) = ? ORDER BY
      " + order, @sub_category.id, @sub_category.id, params[:letter].downcase]))
    elsif params[:letter].present? && ABC.include?(params[:letter]) && @category
      add_breadcrumb params[:letter].upcase, brands_path(letter: params[:letter])
      add_breadcrumb @category.name
      brands = Kaminari.paginate_array(Brand.find_by_sql(["
        SELECT * FROM (
          SELECT brands.*
          FROM brands
          LEFT JOIN products ON products.brand_id = brands.id
          LEFT JOIN products_sub_categories ON products_sub_categories.product_id = products.id
          LEFT JOIN sub_categories ON sub_categories.id = products_sub_categories.sub_category_id
          WHERE sub_categories.category_id = ?
          UNION
          SELECT DISTINCT brands.*
          FROM brands
          INNER JOIN brands_sub_categories
          ON brands_sub_categories.brand_id = brands.id
          LEFT JOIN categories ON categories.id = brands_sub_categories.sub_category_id
          WHERE categories.id = ?
        ) AS brand WHERE left(lower(brand.name),1) = ? ORDER BY
      " + order, @category.id, @category.id, params[:letter].downcase]))
    elsif params[:letter].present? && ABC.include?(params[:letter]) && params[:status].present?
      add_breadcrumb params[:letter].upcase, brands_path(letter: params[:letter])
      add_breadcrumb I18n.t(params[:status])
      brands = Brand.where('left(lower(brands.name),1) = :prefix', prefix: params[:letter].downcase)
                    .where(discontinued: STATUSES.include?(params[:status]) ? params[:status] == 'discontinued' : nil)
                    .order(order)
    elsif @sub_category && params[:status].present?
      @category = Category.find(@sub_category.category_id)
      add_breadcrumb @category.name, brands_path(category: @category.friendly_id)
      add_breadcrumb @sub_category.name, brands_path(sub_category: @sub_category.friendly_id)
      add_breadcrumb I18n.t(params[:status])
      discontinued = STATUSES.include?(params[:status]) && params[:status] == 'discontinued'
      brands = Kaminari.paginate_array(Brand.find_by_sql(["
        SELECT * FROM (
          SELECT brands.*
          FROM brands
          LEFT JOIN products ON products.brand_id = brands.id
          LEFT JOIN products_sub_categories ON products_sub_categories.product_id = products.id
          LEFT JOIN sub_categories ON sub_categories.id = products_sub_categories.sub_category_id
          WHERE sub_categories.id = ?
          UNION
          SELECT DISTINCT brands.*
          FROM brands
          INNER JOIN brands_sub_categories
          ON brands_sub_categories.brand_id = brands.id
          AND brands_sub_categories.sub_category_id = ?
        ) AS brand WHERE brand.discontinued = ? ORDER BY
      " + order, @sub_category.id, @sub_category.id, discontinued]))
    elsif @category && params[:status].present?
      add_breadcrumb @category.name, brands_path(category: @category.friendly_id)
      add_breadcrumb I18n.t(params[:status])
      discontinued = STATUSES.include?(params[:status]) && params[:status] == 'discontinued'
      brands = Kaminari.paginate_array(Brand.find_by_sql(["
        SELECT * FROM (
          SELECT brands.*
          FROM brands
          LEFT JOIN products ON products.brand_id = brands.id
          LEFT JOIN products_sub_categories ON products_sub_categories.product_id = products.id
          LEFT JOIN sub_categories ON sub_categories.id = products_sub_categories.sub_category_id
          WHERE sub_categories.category_id = ?
          UNION
          SELECT DISTINCT brands.*
          FROM brands
          INNER JOIN brands_sub_categories
          ON brands_sub_categories.brand_id = brands.id
          LEFT JOIN categories ON categories.id = brands_sub_categories.sub_category_id
          WHERE categories.id = ?
        ) AS brand WHERE brand.discontinued = ? ORDER BY
      " + order, @category.id, @category.id, discontinued]))
    elsif params[:letter].present? && ABC.include?(params[:letter])
      add_breadcrumb params[:letter].upcase
      brands = Brand.where('left(lower(name),1) = :prefix', prefix: params[:letter].downcase)
                    .order(order)
    elsif @sub_category
      @category = Category.find(@sub_category.category_id)
      add_breadcrumb @category.name, brands_path(category: @category.friendly_id)
      add_breadcrumb @category.name
      brands = Kaminari.paginate_array(Brand.find_by_sql(["
        SELECT * FROM (
          SELECT brands.*
          FROM brands
          LEFT JOIN products ON products.brand_id = brands.id
          LEFT JOIN products_sub_categories ON products_sub_categories.product_id = products.id
          LEFT JOIN sub_categories ON sub_categories.id = products_sub_categories.sub_category_id
          WHERE sub_categories.id = ?
          UNION
          SELECT DISTINCT brands.*
          FROM brands
          INNER JOIN brands_sub_categories
          ON brands_sub_categories.brand_id = brands.id
          AND brands_sub_categories.sub_category_id = ?
        ) AS brand ORDER BY
      " + order, @sub_category.id, @sub_category.id]))
    elsif @category.present?
      add_breadcrumb @category.name
      brands = Kaminari.paginate_array(Brand.find_by_sql(["
        SELECT * FROM (
          SELECT brands.*
          FROM brands
          LEFT JOIN products ON products.brand_id = brands.id
          LEFT JOIN products_sub_categories ON products_sub_categories.product_id = products.id
          LEFT JOIN sub_categories ON sub_categories.id = products_sub_categories.sub_category_id
          WHERE sub_categories.category_id = ?
          UNION
          SELECT DISTINCT brands.*
          FROM brands
          INNER JOIN brands_sub_categories
          ON brands_sub_categories.brand_id = brands.id
          LEFT JOIN categories ON categories.id = brands_sub_categories.sub_category_id
          WHERE categories.id = ?
        ) AS brand ORDER BY
      " + order, @category.id, @category.id]))
    elsif params[:status].present?
      add_breadcrumb I18n.t(params[:status])
      brands = Brand.where(discontinued: STATUSES.include?(params[:status]) ? params[:status] == 'discontinued' : nil)
                    .order(update_for_joined_tables(order))
    else
      brands = Brand.all.order(order)
    end

    @brands_query = params[:query].strip if params[:query].present?
    brands = brands.search_by_name_and_description(@brands_query) if @brands_query.present?

    @brands = brands.page(params[:page])
  end

  def all
    respond_to do |format|
      format.json { render json: { brands: Brand.all.select([:name, :id]).order('LOWER(name)') } }
    end
  end

  def show
    @brand = Brand.friendly.find(params[:id])
    @category = SubCategory.friendly.find(params[:category]) if params[:category].present?

    if @category
      products = @category.products.where(brand_id: @brand.id)
      add_breadcrumb @brand.name, proc { :brand }
      add_breadcrumb @category.name
    else
      products = @brand.products
      add_breadcrumb @brand.name
    end

    if params[:status].present? && STATUSES.include?(params[:status])
      products = products.where(
        discontinued: params[:status] == 'discontinued' ? true : nil
      )
    end

    @brands_query = params[:query].strip if params[:query].present?
    products = products.search_by_name_and_description(@brands_query) if @brands_query.present?

    if params[:letter].present? && ABC.include?(params[:letter])
      products = products.where('left(lower(name),1) = :prefix', prefix: params[:letter].downcase)
    end

    @products = products.includes([:sub_categories]).order('LOWER(name)').page(params[:page])
    @total_products_count = @brand.products.count

    @contributors = User.find_by_sql(["
      SELECT DISTINCT
        users.id, users.user_name, users.profile_visibility,
        versions.item_type, versions.item_id FROM users
      JOIN versions
      ON users.id = CAST(versions.whodunnit AS integer)
      WHERE versions.item_id = ? AND versions.item_type = 'Brand'
    ", @brand.id])

    @all_sub_categories ||= all_sub_categories(@brand).group_by(&:category).sort_by { |category| category[0].order }

    @page_title = @brand.name
  end

  def new
    @page_title = I18n.t('new_brand.heading')

    add_breadcrumb I18n.t('new_brand.heading')

    @sub_category = SubCategory.friendly.find(params[:sub_category]) if params[:sub_category].present?
    @brand = @sub_category ? Brand.new(sub_category_ids: [@sub_category.id]) : Brand.new
    @categories = Category.includes([:sub_categories]).all.order(:order)
  end

  def create
    @brand = Brand.new(brand_params)

    if @brand.save
      redirect_to brand_path(@brand)
    else
      @categories = Category.includes([:sub_categories]).all.order(:order)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @brand = Brand.friendly.find(params[:id])
    @page_title = I18n.t('edit_record', name: @brand.name)
    @categories = Category.includes([:sub_categories]).all.order(:order)

    add_breadcrumb @brand.name, brand_path(@brand)
    add_breadcrumb I18n.t('edit')
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
      @categories = Category.includes([:sub_categories]).all.order(:order)
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
      .sub('LOWER(name)', 'LOWER(brands.name)')
      .sub('products_count', 'brands.products_count')
      .sub('country_code', 'brands.country_code')
      .sub('created_at', 'brands.created_at')
      .sub('updated_at', 'brands.updated_at')
  end

  def set_active_menu
    @active_menu = :brands
  end

  def set_breadcrumb
    add_breadcrumb I18n.t('headings.brands'), brands_path
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
