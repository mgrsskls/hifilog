class CustomProductsController < ApplicationController
  before_action :authenticate_user!, except: [:show]
  before_action :set_menu, except: [:show]

  def index
    @page_title = CustomProduct.model_name.human(count: 2)

    @custom_products = current_user.custom_products
                                   .includes([:images_attachments])
                                   .includes([:sub_categories])
                                   .order(:name).map do |custom_product|
      CustomProductPresenter.new(custom_product)
    end
  end

  def show
    @user = User.find_by('lower(user_name) = ?', params[:user_id].downcase)

    possession = @user.possessions.find_by(custom_product_id: params[:id])
    @possession = CustomProductPossessionPresenter.new(possession) if possession

    @custom_product = CustomProductPresenter.new(@user.custom_products.find(params[:id]))

    unless current_user == @user
      redirect_path = get_redirect_if_unauthorized(@user, @custom_product)
      return redirect_to redirect_path if redirect_path
    end

    @setups = current_user.setups if @user == current_user

    @page_title = @custom_product.display_name
  end

  def new
    @custom_product = CustomProduct.new
    @categories = Category.includes([:sub_categories])

    @page_title = I18n.t('custom_product.new.heading')
  end

  def edit
    @custom_product = current_user.custom_products.find(params[:id])
    @categories = Category.includes([:sub_categories])

    @page_title = "#{t('edit')} #{@custom_product.name}"
  end

  def create
    @custom_product = current_user.custom_products.new custom_product_params

    if @custom_product.save
      possession = Possession.new(
        user: current_user,
        custom_product: @custom_product,
      )
      possession.save

      flash[:notice] = I18n.t(
        'custom_product.messages.created',
        name: @custom_product.name
      )
      redirect_to user_custom_product_path(id: @custom_product.id, user_id: current_user.user_name.downcase)
    else
      @active_dashboard_menu = :custom_products
      @categories = Category.includes([:sub_categories])
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @custom_product = current_user.custom_products.find(params[:id])
    @categories = Category.includes([:sub_categories])

    if @custom_product.update(custom_product_params)
      flash[:notice] = I18n.t(
        'custom_product.messages.updated',
        link: ActionController::Base.helpers.link_to(
          @custom_product.name,
          user_custom_product_path(id: @custom_product.id, user_id: current_user.user_name.downcase)
        )
      )

      params[:delete_image]&.each do |id|
        image = @custom_product.images.find(id)
        image.purge
      end

      redirect_back fallback_location: user_custom_product_url(
        user_id: @custom_product.user.user_name.downcase,
        id: @custom_product.id
      )
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @custom_product = current_user.custom_products.find(params[:id])
    @custom_product.destroy
    flash[:notice] = I18n.t('custom_product.messages.deleted', name: @custom_product.name)
    redirect_to dashboard_custom_products_path
  end

  private

  def set_menu
    @active_dashboard_menu = :custom_products
    @active_menu = :dashboard
  end

  def custom_product_params
    if params[:delete_image]&.include?(params[:custom_product][:highlighted_image_id])
      params[:custom_product][:highlighted_image_id] = nil
    end

    params.expect(custom_product: [:name, :description, :highlighted_image_id, { sub_category_ids: [], images: [] }])
  end

  def get_redirect_if_unauthorized(user, custom_product)
    return if user.visible?

    # if visited profile is not visible to logged out users and the current user is logged in
    return if user.logged_in_only? && user_signed_in?

    # if the visited profile is not visible to anyone and the visiting user is a different user
    return root_url if user.hidden? && current_user != user

    redir = user_custom_product_path(id: custom_product.id, user_id: user.user_name.downcase)
    new_user_session_url(redirect: URI.parse(redir).path)
  end
end
