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
      # order = 'price ASC, LOWER(name)' if params[:sort] == 'price_asc'
      # order = 'price DESC, LOWER(name)' if params[:sort] == 'price_desc'
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
      @custom_attributes = @sub_category.custom_attributes
    elsif params[:category].present?
      @category = Category.friendly.find(params[:category])

      if @category
        @custom_attributes = CustomAttribute.joins(:sub_categories)
                                            .where(sub_categories: { id: @category.sub_categories.map(&:id) })
                                            .distinct
      end
    end

    if params[:letter].present? && @sub_category && params[:status].present?
      add_breadcrumb params[:letter].upcase, products_path(letter: params[:letter])
      add_breadcrumb @category.name, products_path(letter: params[:letter], category: @category.friendly_id)
      add_breadcrumb @sub_category.name, products_path(letter: params[:letter], sub_category: @sub_category.friendly_id)
      add_breadcrumb I18n.t(params[:status])
      products = Product.joins(:sub_categories)
                        .where(sub_categories: @sub_category.id)
                        .where('left(lower(products.name),1) = :prefix', prefix: params[:letter].downcase)
                        .where(
                          discontinued: STATUSES.include?(params[:status]) ? params[:status] == 'discontinued' : nil
                        )
                        .order(update_for_joined_tables(order))
    elsif params[:letter].present? && @category && params[:status].present?
      add_breadcrumb params[:letter].upcase, products_path(letter: params[:letter])
      add_breadcrumb @category.name, products_path(letter: params[:letter], category: @category.friendly_id)
      add_breadcrumb I18n.t(params[:status])
      products = Product.joins(:sub_categories)
                        .where(sub_categories: { category_id: @category.id })
                        .where('left(lower(products.name),1) = :prefix', prefix: params[:letter].downcase)
                        .where(
                          discontinued: STATUSES.include?(params[:status]) ? params[:status] == 'discontinued' : nil
                        )
                        .order(update_for_joined_tables(order))
    elsif params[:letter].present? && @sub_category
      add_breadcrumb params[:letter].upcase, products_path(letter: params[:letter])
      add_breadcrumb @category.name, products_path(category: @category.friendly_id)
      add_breadcrumb @sub_category.name
      products = Product.joins(:sub_categories)
                        .where(sub_categories: @sub_category.id)
                        .where('left(lower(products.name),1) = :prefix', prefix: params[:letter].downcase)
                        .order(update_for_joined_tables(order))
    elsif params[:letter].present? && @category
      add_breadcrumb params[:letter].upcase, products_path(letter: params[:letter])
      add_breadcrumb @category.name
      products = Product.joins(:sub_categories)
                        .where(sub_categories: { category_id: @category.id })
                        .where('left(lower(products.name),1) = :prefix', prefix: params[:letter].downcase)
                        .order(update_for_joined_tables(order))
    elsif params[:letter].present? && params[:status].present?
      add_breadcrumb params[:letter].upcase, products_path(letter: params[:letter])
      add_breadcrumb I18n.t(params[:status])
      products = Product.where('left(lower(products.name),1) = :prefix', prefix: params[:letter].downcase)
                        .where(
                          discontinued: STATUSES.include?(params[:status]) ? params[:status] == 'discontinued' : nil
                        )
                        .order(update_for_joined_tables(order))
    elsif @sub_category && params[:status].present?
      add_breadcrumb @category.name, products_path(category: @category.friendly_id)
      add_breadcrumb @sub_category.name, products_path(sub_category: @sub_category.friendly_id)
      add_breadcrumb I18n.t(params[:status])
      products = Product.joins(:sub_categories)
                        .where(sub_categories: @sub_category.id)
                        .where(
                          discontinued: STATUSES.include?(params[:status]) ? params[:status] == 'discontinued' : nil
                        )
                        .order(update_for_joined_tables(order))
    elsif @category && params[:status].present?
      add_breadcrumb @category.name, products_path(category: @category.friendly_id)
      add_breadcrumb I18n.t(params[:status])
      products = Product.joins(:sub_categories)
                        .where(sub_categories: { category_id: @category.id })
                        .where(
                          discontinued: STATUSES.include?(params[:status]) ? params[:status] == 'discontinued' : nil
                        )
                        .order(update_for_joined_tables(order))
    elsif params[:letter].present?
      add_breadcrumb params[:letter].upcase
      products = Product.where('left(lower(name),1) = :prefix', prefix: params[:letter].downcase)
                        .order(order)
    elsif @sub_category
      add_breadcrumb @category.name, products_path(category: @category.friendly_id)
      add_breadcrumb @sub_category.name
      products = Product.joins(:sub_categories)
                        .where(sub_categories: @sub_category.id)
                        .order(update_for_joined_tables(order))
    elsif @category
      add_breadcrumb @category.name
      products = Product.joins(:sub_categories)
                        .where(sub_categories: { category_id: @category.id })
                        .order(update_for_joined_tables(order))
    elsif params[:status].present?
      add_breadcrumb I18n.t(params[:status])
      products = Product.where(discontinued:
                          STATUSES.include?(params[:status]) ? params[:status] == 'discontinued' : nil)
                        .order(order)
    else
      products = Product.all.order(order)
    end

    CustomAttribute.all.find_each do |custom_attribute|
      id_s = custom_attribute.id.to_s
      if params[:attr].present? && params[:attr][id_s].present?
        products = products.where('custom_attributes ->> ? = ?', id_s, params[:attr][id_s])
      end
    end

    @products_query = params[:query].strip if params[:query].present?
    products = products.search_by_name_and_description(@products_query) if @products_query.present?

    @products = products.includes([:brand, :sub_categories, :product_variants]).page(params[:page])
  end

  def show
    @brand = @product.brand

    if user_signed_in?
      @possessions = current_user.possessions.where(product_id: @product.id, product_variant_id: nil)
      @bookmark = current_user.bookmarks.find_by(product_id: @product.id, product_variant_id: nil)
      @prev_owned = current_user.prev_owneds.find_by(product_id: @product.id, product_variant_id: nil)
      @note = current_user.notes.find_by(product_id: @product.id, product_variant_id: nil)
      @setups = current_user.setups.includes(:possessions)
    end

    @public_possessions_with_image = @product.possessions
                                             .joins(:user)
                                             .where(user: { profile_visibility: user_signed_in? ? [1, 2] : 2 })
                                             .select { |possession| possession.image.attached? }

    @contributors = ActiveRecord::Base.connection.execute("
      SELECT DISTINCT
        users.id, users.user_name, users.profile_visibility,
        versions.item_type, versions.item_id FROM users
      JOIN versions
      ON users.id = CAST(versions.whodunnit AS integer)
      WHERE versions.item_id = #{@product.id} AND versions.item_type = 'Product'
    ")

    add_breadcrumb @product.display_name
    @page_title = "#{@product.brand.name if @product.brand.present?} #{@product.name}".strip
  end

  def new
    @page_title = I18n.t('new_product.heading')

    @sub_category = SubCategory.friendly.find(params[:sub_category]) if params[:sub_category].present?
    @product = @sub_category ? Product.new(sub_category_ids: [@sub_category.id]) : Product.new
    @product.custom_attributes = {}
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

      if (product_params[:sub_category_ids] - @brand.sub_category_ids).any?
        (product_params[:sub_category_ids] - @brand.sub_category_ids).each do |id|
          sub_category = SubCategory.find(id.to_i)
          @brand.sub_categories << sub_category if sub_category && !@brand.sub_categories.include?(sub_category)
        end
      end

      @product = Product.new(
        name: product_params[:name],
        brand_id: product_params[:brand_id],
        discontinued: @brand.discontinued ? true : product_params[:discontinued],
        release_day: product_params[:release_day],
        release_month: product_params[:release_month],
        release_year: product_params[:release_year],
        discontinued_day: product_params[:discontinued_day],
        discontinued_month: product_params[:discontinued_month],
        discontinued_year: product_params[:discontinued_year],
        description: product_params[:description],
        price: product_params[:price],
        price_currency: product_params[:price_currency],
        custom_attributes: product_params[:custom_attributes],
        sub_category_ids: product_params[:sub_category_ids],
      )

      if @product.save && @brand.save
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
          discontinued_day: product_params[:discontinued_day],
          discontinued_month: product_params[:discontinued_month],
          discontinued_year: product_params[:discontinued_year],
          description: product_params[:description],
          price: product_params[:price],
          price_currency: product_params[:price_currency],
          custom_attributes: product_params[:custom_attributes],
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
    @product = Product.friendly.find(params[:id])
    @page_title = I18n.t('edit_record', name: @product.name)
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

    if product_update_params[:custom_attributes].present?
      product_update_params[:custom_attributes].each do |custom_attribute|
        custom_attribute[1] = custom_attribute[1].to_i
      end
    else
      @product.custom_attributes = {}
    end

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

    add_breadcrumb @product.display_name, product_path(id: @product.friendly_id)
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
            :discontinued_day,
            :discontinued_month,
            :discontinued_year,
            :description,
            :price,
            :price_currency,
            custom_attributes: {},
            sub_category_ids: [],
            brand_attributes: [
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
              :description
            ]
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
            :discontinued_day,
            :discontinued_month,
            :discontinued_year,
            :description,
            :price,
            :price_currency,
            :comment,
            custom_attributes: {},
            sub_category_ids: [],
          )
  end
end
