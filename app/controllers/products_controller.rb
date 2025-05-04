class ProductsController < ApplicationController
  include ApplicationHelper

  before_action :set_paper_trail_whodunnit, only: [:create, :update]
  before_action :authenticate_user!, only: [:new, :create, :edit, :update, :changelog]
  before_action :set_breadcrumb, only: [:show, :new, :edit, :changelog]
  before_action :set_active_menu
  before_action :find_product, only: [:show]

  def index
    @page_title = Product.model_name.human(count: 2)

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
            when 'added_asc'
              'products.created_at ASC, LOWER(products.name)'
            when 'added_desc'
              'products.created_at DESC, LOWER(products.name)'
            when 'updated_asc'
              'products.updated_at ASC, LOWER(products.name)'
            when 'updated_desc'
              'products.updated_at DESC, LOWER(products.name)'
            else
              'LOWER(products.name) ASC'
            end

    @sub_category = SubCategory.friendly.find(params[:sub_category]) if params[:sub_category].present?

    if @sub_category
      @category = Category.find(@sub_category.category_id)
      @custom_attributes = @sub_category.custom_attributes
      add_breadcrumb Product.model_name.human(count: 2), proc { :products }
      add_breadcrumb @category.name, products_path(category: @category.friendly_id)
      add_breadcrumb @sub_category.name
    elsif params[:category].present?
      @category = Category.friendly.find(params[:category])
      add_breadcrumb Product.model_name.human(count: 2), proc { :products }
      add_breadcrumb @category.name

      if @category
        @custom_attributes = CustomAttribute.joins(:sub_categories)
                                            .where(sub_categories: { id: @category.sub_categories.map(&:id) })
                                            .distinct
      end
    else
      add_breadcrumb Product.model_name.human(count: 2)
    end

    products = Product.all

    if ABC.include?(params[:letter])
      products = products.where('left(lower(products.name),1) = :prefix', prefix: params[:letter].downcase)
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

      products = if params[:diy_kit] == '0'
                   products.where(product_variants: { diy_kit: false })
                           .or(
                             products.where(diy_kit: false)
                           )
                 else
                   products.where(product_variants: { diy_kit: true })
                           .or(
                             products.where(diy_kit: true)
                           )
                 end
      @filter_applied = true
    end

    if params[:country].present?
      products = products.joins(:brand).where(brand: { country_code: params[:country].upcase })
      @filter_applied = true
    end

    if params[:attr].present?
      CustomAttribute.find_each do |custom_attribute|
        id_s = custom_attribute.id.to_s
        if params[:attr][id_s].present?
          products = products.where('custom_attributes ->> ? IN (?)', id_s, params[:attr][custom_attribute.id.to_s])
          @filter_applied = true
        end
      end
    end

    if params[:query].present?
      @products_query = params[:query].strip
      if @products_query.present?
        products = products.left_outer_joins(:product_variants)
                           .where(
                             'product_variants.name ILIKE ? AND product_variants.discontinued IN (?)',
                             "%#{@products_query}%",
                             STATUSES.include?(params[:status]) ? [params[:status] == 'discontinued'] : [true, false]
                           )
                           .or(
                             products.where('products.name ILIKE ?', "%#{@products_query}%")
                           )
        @filter_applied = true
      end
    end

    if @sub_category || @category
      products = if @sub_category
                   products.joins(:sub_categories)
                           .where(sub_categories: @sub_category.id)
                 else
                   products.joins(:sub_categories)
                           .where(sub_categories: { category_id: @category.id })
                 end
    end

    @products = products.order(order)
                        .distinct
                        .select('products.*, LOWER(products.name)')
                        .includes(:brand)
                        .includes(:product_variants)
                        .includes(sub_categories: [:custom_attributes])
                        .page(params[:page])
  end

  def show
    @brand = @product.brand

    if user_signed_in?
      @possessions = current_user.possessions
                                 .includes([:product, :product_option, :setup_possession, :setup])
                                 .where(product_id: @product.id, product_variant_id: nil)
                                 .order([:prev_owned, :period_from, :period_to, :created_at])
                                 .map do |possession|
                                   if possession.prev_owned
                                     PreviousPossessionPresenter.new(possession, :product)
                                   else
                                     CurrentPossessionPresenter.new(possession, :product)
                                   end
                                 end
      @bookmark = current_user.bookmarks.find_by(product_id: @product.id, product_variant_id: nil)
      @note = current_user.notes.find_by(product_id: @product.id, product_variant_id: nil)
      @setups = current_user.setups.includes(:possessions)
    end

    @images = @product.possessions
                      .includes([:images_attachments])
                      .joins(:user)
                      .where(user: { profile_visibility: user_signed_in? ? [1, 2] : 2 })
                      .select { |possession| possession.images.attached? }
                      .map { |possession| PossessionPresenter.new possession }
                      .flat_map(&:sorted_images)
                      .map { |image| ImagePresenter.new image }

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
    @page_title = I18n.t('product.new.heading')

    @sub_category = SubCategory.friendly.find(params[:sub_category]) if params[:sub_category].present?
    @product = @sub_category ? Product.new(sub_category_ids: [@sub_category.id]) : Product.new
    @brand = @product.build_brand
    @brands = Brand.order('LOWER(name)')
    @categories = Category.includes([:sub_categories])

    if params[:brand_id].present?
      @product.brand_id = params[:brand_id]
      @brand = Brand.find(params[:brand_id])

      add_breadcrumb @brand.display_name, brand_path(@brand)
    end

    add_breadcrumb t('add_product')
  end

  def edit
    @product = Product.friendly.find(params[:id])
    @page_title = I18n.t('edit_record', name: @product.name)
    @brand = @product.brand
    @categories = Category.includes([:sub_categories])

    add_breadcrumb @product.display_name, product_path(id: @product.friendly_id)
    add_breadcrumb I18n.t('edit')
  end

  def create
    product = Product.new(product_params)

    if product_params[:brand_id].present?
      brand = Brand.find(product_params[:brand_id]) if product_params[:brand_id]

      sub_category_ids = product_params[:sub_category_ids]
      if sub_category_ids.present? && (sub_category_ids - brand.sub_category_ids).any?
        (sub_category_ids - brand.sub_category_ids).each do |id|
          sub_category = SubCategory.find(id.to_i)
          brand.sub_categories << sub_category if sub_category && brand.sub_categories.exclude?(sub_category)
        end
      end
    else
      brand = Brand.new(product_params[:brand_attributes])
      sub_category_ids = product_params[:sub_category_ids]
      if sub_category_ids.present?
        sub_category_ids.each do |id|
          sub_category = SubCategory.find(id.to_i)
          brand.sub_categories << sub_category if sub_category
        end
      end
    end

    unless brand.save
      if params[:product_options_attributes].present?
        params[:product_options_attributes].each do |option|
          if option[1][:id].present? && option[1][:option].present?
            product.product_options.find(option[1][:id]).update(option: option[1][:option])
          elsif option[1][:id].present?
            product.product_options.find(option[1][:id]).delete
          elsif option[1][:option].present?
            product.product_options << ProductOption.new(option: option[1][:option])
          end
        end
      end
      @categories = Category.includes([:sub_categories])
      @product = product
      @brand = brand
      render :new, status: :unprocessable_entity
      return
    end

    product.brand_id = brand.id
    product.discontinued = brand.discontinued ? true : product_params[:discontinued]

    if params[:product_options_attributes].present?
      params[:product_options_attributes].each do |option|
        if option[1][:id].present? && option[1][:option].present?
          product.product_options.find(option[1][:id]).update(option: option[1][:option])
        elsif option[1][:id].present?
          product.product_options.find(option[1][:id]).delete
        elsif option[1][:option].present?
          product.product_options << ProductOption.new(option: option[1][:option])
        end
      end
    end

    if product.save
      redirect_to URI.parse(product_url(id: product.friendly_id)).path
    else
      @categories = Category.includes([:sub_categories])
      @product = product
      @brand = brand
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @product = Product.find(params[:id])

    old_name = @product.name
    @product.slug = nil if old_name != product_update_params[:name]

    if product_update_params[:custom_attributes].present?
      product_update_params[:custom_attributes].each do |custom_attribute|
        custom_attribute[1] = custom_attribute[1].to_i
      end
    end

    if params[:product_options_attributes].present?
      params[:product_options_attributes].each do |option|
        if option[1][:id].present? && option[1][:option].present?
          @product.product_options.find(option[1][:id]).update(option: option[1][:option])
        elsif option[1][:id].present?
          @product.product_options.find(option[1][:id]).delete
        elsif option[1][:option].present?
          @product.product_options << ProductOption.new(option: option[1][:option])
        end
      end
    end

    if @product.update(product_update_params)
      redirect_to URI.parse(product_url(id: @product.friendly_id)).path
    else
      @categories = Category
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
    add_breadcrumb Product.model_name.human(count: 2), products_path
  end

  def product_params
    if params[:product][:product_options_attributes].present?
      options = {}

      params[:product][:product_options_attributes].each do |i, product_option|
        options[i] = product_option if product_option[:option].present?
      end

      params[:product][:product_options_attributes] = options
    end

    params
      .expect(
        product: [:name,
                  :brand_id,
                  :discontinued,
                  :diy_kit,
                  :release_day,
                  :release_month,
                  :release_year,
                  :discontinued_day,
                  :discontinued_month,
                  :discontinued_year,
                  :description,
                  :price,
                  :price_currency,
                  { custom_attributes: {},
                    sub_category_ids: [],
                    product_options_attributes: {},
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
                    ] }]
      )
  end

  def product_update_params
    params
      .expect(
        product: [:name,
                  :discontinued,
                  :diy_kit,
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
                  { custom_attributes: {},
                    sub_category_ids: [] }],
      )
  end
end
