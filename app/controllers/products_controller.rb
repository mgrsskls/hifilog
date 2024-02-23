class ProductsController < ApplicationController
  include ApplicationHelper

  STATUSES = %w[discontinued continued].freeze

  before_action :set_paper_trail_whodunnit, only: [:create, :update]
  before_action :authenticate_user!, only: [:new, :create, :edit, :update, :changelog]
  before_action :set_breadcrumb, only: [:show, :new, :edit, :changelog]
  before_action :set_active_menu
  before_action :find_product, only: [:show]

  def index
    @page_title = I18n.t('headings.products')

    if (params[:letter].present? && ABC.include?(params[:letter])) ||
       params[:category].present? ||
       params[:sub_category].present? ||
       params[:status].present?
      add_breadcrumb I18n.t('headings.products'), proc { :products }
    else
      add_breadcrumb I18n.t('headings.products')
    end

    if params[:sort].present?
      order = 'LOWER(name) ASC' if params[:sort] == 'name_asc'
      order = 'LOWER(name) DESC' if params[:sort] == 'name_desc'
      if params[:sort] == 'release_date_asc'
        order = 'release_year ASC NULLS LAST, release_month ASC NULLS LAST, release_day ASC NULLS LAST, LOWER(name)'
      end
      if params[:sort] == 'release_date_desc'
        order = 'release_year DESC NULLS LAST, release_month DESC NULLS LAST, release_day DESC NULLS LAST, LOWER(name)'
      end
      order = 'created_at ASC, LOWER(name)' if params[:sort] == 'added_asc'
      order = 'created_at DESC, LOWER(name)' if params[:sort] == 'added_desc'
      order = 'updated_at ASC, LOWER(name)' if params[:sort] == 'updated_asc'
      order = 'updated_at DESC, LOWER(name)' if params[:sort] == 'updated_desc'
    else
      order = 'LOWER(name) ASC'
    end

    if params[:letter].present? && params[:sub_category].present? && params[:status].present?
      @sub_category = SubCategory.friendly.find(params[:sub_category])
      @category = Category.find(@sub_category.category_id)
      add_breadcrumb params[:letter].upcase, products_path(letter: params[:letter])
      add_breadcrumb @category.name, products_path(letter: params[:letter], category: @category.friendly_id)
      add_breadcrumb @sub_category.name, products_path(letter: params[:letter], sub_category: @sub_category.friendly_id)
      add_breadcrumb I18n.t(params[:status])
      @products = Product.joins(:sub_categories)
                         .where(sub_categories: @sub_category.id)
                         .where('left(lower(products.name),1) = :prefix', prefix: params[:letter].downcase)
                         .where(
                           discontinued: STATUSES.include?(params[:status]) ? params[:status] == 'discontinued' : nil
                         )
                         .includes([:brand, :sub_categories])
                         .order(update_for_joined_tables(order))
                         .page(params[:page])
    elsif params[:letter].present? && params[:category].present? && params[:status].present?
      @category = Category.friendly.find(params[:category])
      add_breadcrumb params[:letter].upcase, products_path(letter: params[:letter])
      add_breadcrumb @category.name, products_path(letter: params[:letter], category: @category.friendly_id)
      add_breadcrumb I18n.t(params[:status])
      @products = Product.joins(:sub_categories)
                         .where(sub_categories: { category_id: @category.id })
                         .where('left(lower(products.name),1) = :prefix', prefix: params[:letter].downcase)
                         .where(
                           discontinued: STATUSES.include?(params[:status]) ? params[:status] == 'discontinued' : nil
                         )
                         .includes([:brand, :sub_categories])
                         .order(update_for_joined_tables(order))
                         .page(params[:page])
    elsif params[:letter].present? && params[:sub_category].present?
      @sub_category = SubCategory.friendly.find(params[:sub_category])
      @category = Category.find(@sub_category.category_id)
      add_breadcrumb params[:letter].upcase, products_path(letter: params[:letter])
      add_breadcrumb @category.name, products_path(category: @category.friendly_id)
      add_breadcrumb @sub_category.name
      @products = Product.joins(:sub_categories)
                         .where(sub_categories: @sub_category.id)
                         .where('left(lower(products.name),1) = :prefix', prefix: params[:letter].downcase)
                         .includes([:brand, :sub_categories])
                         .order(update_for_joined_tables(order))
                         .page(params[:page])
    elsif params[:letter].present? && params[:category].present?
      @category = Category.friendly.find(params[:category])
      add_breadcrumb params[:letter].upcase, products_path(letter: params[:letter])
      add_breadcrumb @category.name
      @products = Product.joins(:sub_categories)
                         .where(sub_categories: { category_id: @category.id })
                         .where('left(lower(products.name),1) = :prefix', prefix: params[:letter].downcase)
                         .includes([:brand, :sub_categories])
                         .order(update_for_joined_tables(order))
                         .page(params[:page])
    elsif params[:letter].present? && params[:status].present?
      add_breadcrumb params[:letter].upcase, products_path(letter: params[:letter])
      add_breadcrumb I18n.t(params[:status])
      @products = Product.where('left(lower(products.name),1) = :prefix', prefix: params[:letter].downcase)
                         .where(
                           discontinued: STATUSES.include?(params[:status]) ? params[:status] == 'discontinued' : nil
                         )
                         .includes([:brand, :sub_categories])
                         .order(update_for_joined_tables(order))
                         .page(params[:page])
    elsif params[:sub_category].present? && params[:status].present?
      @sub_category = SubCategory.friendly.find(params[:sub_category])
      @category = Category.find(@sub_category.category_id)
      add_breadcrumb @category.name, products_path(category: @category.friendly_id)
      add_breadcrumb @sub_category.name, products_path(sub_category: @sub_category.friendly_id)
      add_breadcrumb I18n.t(params[:status])
      @products = Product.joins(:sub_categories)
                         .where(sub_categories: @sub_category.id)
                         .where(
                           discontinued: STATUSES.include?(params[:status]) ? params[:status] == 'discontinued' : nil
                         )
                         .includes([:brand, :sub_categories])
                         .order(update_for_joined_tables(order))
                         .page(params[:page])
    elsif params[:category].present? && params[:status].present?
      @category = Category.friendly.find(params[:category])
      add_breadcrumb @category.name, products_path(category: @category.friendly_id)
      add_breadcrumb I18n.t(params[:status])
      @products = Product.joins(:sub_categories)
                         .where(sub_categories: { category_id: @category.id })
                         .where(
                           discontinued: STATUSES.include?(params[:status]) ? params[:status] == 'discontinued' : nil
                         )
                         .includes([:brand, :sub_categories])
                         .order(update_for_joined_tables(order))
                         .page(params[:page])
    elsif params[:letter].present?
      add_breadcrumb params[:letter].upcase
      @products = Product.where('left(lower(name),1) = :prefix', prefix: params[:letter].downcase)
                         .includes([:brand, :sub_categories])
                         .order(order)
                         .page(params[:page])
    elsif params[:sub_category].present?
      @sub_category = SubCategory.friendly.find(params[:sub_category])
      @category = Category.find(@sub_category.category_id)
      add_breadcrumb @category.name, products_path(category: @category.friendly_id)
      add_breadcrumb @sub_category.name
      @products = Product.joins(:sub_categories)
                         .where(sub_categories: @sub_category.id)
                         .includes([:brand, :sub_categories])
                         .order(update_for_joined_tables(order))
                         .page(params[:page])
    elsif params[:category].present?
      @category = Category.friendly.find(params[:category])
      add_breadcrumb @category.name
      @products = Product.joins(:sub_categories)
                         .where(sub_categories: { category_id: params[:category] })
                         .includes([:brand, :sub_categories])
                         .order(update_for_joined_tables(order))
                         .page(params[:page])
    elsif params[:status].present?
      add_breadcrumb I18n.t(params[:status])
      @products = Product.where(discontinued:
                           STATUSES.include?(params[:status]) ? params[:status] == 'discontinued' : nil)
                         .includes([:brand, :sub_categories])
                         .order(order)
                         .page(params[:page])
    else
      @products = Product.all
                         .includes([:brand, :sub_categories])
                         .order(order)
                         .page(params[:page])
    end
  end

  def show
    @product = Product.friendly.find(params[:id])
    @brand = @product.brand

    if user_signed_in?
      @bookmark = current_user.bookmarks.find_by(product_id: @product.id)
      @prev_owned = current_user.prev_owneds.find_by(product_id: @product.id)
      @setups = current_user.setups.includes(:products)
    end

    @contributors = ActiveRecord::Base.connection.execute("
      SELECT DISTINCT
        users.id, users.user_name, users.profile_visibility,
        versions.item_type, versions.item_id FROM users
      JOIN versions
      ON users.id = CAST(versions.whodunnit AS integer)
      WHERE versions.item_id = #{@product.id} AND versions.item_type = 'Product'
    ")

    add_breadcrumb @product.display_name
    @page_title = "#{@product.brand.name} #{@product.name}"
  end

  def new
    @page_title = I18n.t('new_product.heading')

    @sub_category = SubCategory.friendly.find(params[:sub_category]) if params[:sub_category].present?
    @product = @sub_category ? Product.new(sub_category_ids: [@sub_category.id]) : Product.new
    @product.build_brand
    @brands = Brand.all.order('LOWER(name)')
    @categories = Category.includes([:sub_categories]).all.order(:order)

    if params[:brand_id].present?
      @product.brand_id = params[:brand_id]
      @brand = Brand.find(params[:brand_id])

      add_breadcrumb @brand.display_name, brand_path(@brand)
    end

    add_breadcrumb t('add_product')
  end

  def create
    if product_params[:brand_id].present?
      @brand = Brand.find(product_params[:brand_id]) if product_params[:brand_id]
      @product = Product.new(
        name: product_params[:name],
        brand_id: product_params[:brand_id],
        discontinued: @brand.discontinued ? true : product_params[:discontinued],
        release_day: product_params[:release_day],
        release_month: product_params[:release_month],
        release_year: product_params[:release_year],
        description: product_params[:description],
        sub_category_ids: product_params[:sub_category_ids],
      )
      if @product.save
        redirect_to URI.parse(product_url(id: @product.friendly_id)).path
      else
        @brands = Brand.all.order('LOWER(name)')
        @categories = Category.ordered
        render :new, status: :unprocessable_entity
      end
    else
      brand = Brand.new(product_params[:brand_attributes])

      if brand.save
        @product = Product.new(
          name: product_params[:name],
          brand_id: brand.id,
          discontinued: brand.discontinued ? true : product_params[:discontinued],
          release_day: product_params[:release_day],
          release_month: product_params[:release_month],
          release_year: product_params[:release_year],
          description: product_params[:description],
          sub_category_ids: product_params[:sub_category_ids],
        )

        if @product.save
          redirect_to URI.parse(product_url(id: @product.friendly_id)).path
        else
          @brands = Brand.all.order('LOWER(name)')
          @categories = Category.ordered
          @brand = brand
          render :new, status: :unprocessable_entity
        end
      else
        @brands = Brand.all.order('LOWER(name)')
        @categories = Category.ordered
        @product = Product.new(product_params)
        @brand = brand
        render :new, status: :unprocessable_entity
      end
    end
  end

  def edit
    @page_title = I18n.t('new_product.heading')

    @product = Product.friendly.find(params[:id])
    @brand = @product.brand
    @brands = Brand.all.order('LOWER(name)')
    @categories = Category.includes([:sub_categories]).ordered

    add_breadcrumb @product.display_name, product_path(id: @product.friendly_id)
    add_breadcrumb I18n.t('edit')
  end

  def update
    @product = Product.find(params[:id])

    old_name = @product.name
    @product.slug = nil if old_name != product_update_params[:name]

    if @product.update(product_update_params)
      redirect_to URI.parse(product_url(id: @product.friendly_id)).path
    else
      @brands = Brand.all.order('LOWER(name)')
      @categories = Category.ordered
      @brand = Brand.find(@product.brand_id)
      render :edit, status: :unprocessable_entity
    end
  end

  def changelog
    @product = Product.friendly.find(params[:product_id])
    @brand = @product.brand
    @versions = @product.versions.select do |v|
      log = get_changelog(v.object_changes)
      log.length > 1 || (log.length == 1 && log['slug'].nil?)
    end

    add_breadcrumb @product.display_name, product_path(id: @product.id)
    add_breadcrumb I18n.t('headings.changelog')
  end

  private

  def find_product
    @product = Product.friendly.find(params[:id])

    return unless request.path != product_path(@product)

    # If an old id or a numeric id was used to find the record, then
    # the request path will not match the product_path, and we should do
    # a 301 redirect that uses the current friendly id.
    redirect_to URI.parse(product_path(@product)).path, status: :moved_permanently
  end

  def update_for_joined_tables(order)
    order
      .sub('LOWER(name)', 'LOWER(products.name)')
      .sub('release_year', 'products.release_year')
      .sub('release_month', 'products.release_month')
      .sub('release_day', 'products.release_day')
      .sub('created_at', 'products.created_at')
      .sub('updated_at', 'products.updated_at')
  end

  def set_active_menu
    @active_menu = :products
  end

  def set_breadcrumb
    add_breadcrumb I18n.t('headings.products'), products_path
  end

  def product_params
    params.require(:product)
          .permit(
            :name,
            :brand_id,
            :discontinued,
            :release_day,
            :release_month,
            :release_year,
            :description,
            sub_category_ids: [],
            brand_attributes: [:name, :discontinued, :full_name, :website, :country_code, :year_founded, :description]
          )
  end

  def product_update_params
    params.require(:product)
          .permit(
            :name,
            :discontinued,
            :release_day,
            :release_month,
            :release_year,
            :description,
            sub_category_ids: []
          )
  end
end
