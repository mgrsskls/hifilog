class CustomProductsController < ApplicationController
  before_action :authenticate_user!, except: [:show]
  before_action :set_breadcrumb, except: [:show]

  def index
    @page_title = I18n.t('headings.setups')
    @custom_products = current_user.possessions
                                   .where.not(custom_product_id: nil)
                                   .map { |possession| CustomProductPresenter.new(possession) }
                                   .sort_by(&:name)
  end

  def show
    @user = User.find_by('lower(user_name) = ?', (params[:user_id].presence || params[:id]).downcase)
    possession = @user.possessions.find_by(custom_product_id: params[:id])

    return render 'not_found', status: :not_found if possession.nil?

    @possession = CustomProductPresenter.new(possession)

    unless current_user == @user
      redirect_path = get_redirect_if_unauthorized(@user, @possession)
      return redirect_to redirect_path if redirect_path
    end

    @setups = current_user.setups if @user == current_user

    add_breadcrumb I18n.t('users'), users_path
    add_breadcrumb @user.user_name, user_path(id: @user.user_name.downcase)
    add_breadcrumb @possession.name
    @page_title = @possession.name
  end

  def new
    @custom_product = CustomProduct.new
    @categories = Category.ordered

    add_breadcrumb I18n.t('new_custom_product.breadcrumb')
  end

  def create
    @custom_product = CustomProduct.new(custom_product_params)
    possession = Possession.new(user: current_user, custom_product: @custom_product)

    if @custom_product.save && possession.save
      flash[:notice] = I18n.t(
        'custom_products.created',
        name: @custom_product.name
      )
      redirect_to user_custom_product_path(id: @custom_product.id, user_id: current_user.user_name.downcase)
    else
      @active_dashboard_menu = :custom_products
      @categories = Category.ordered
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @custom_product = current_user.custom_products.find(params[:id])
    @categories = Category.ordered

    add_breadcrumb @custom_product.name, user_custom_product_path(
      id: @custom_product.id,
      user_id: current_user.user_name.downcase
    )
    add_breadcrumb I18n.t('edit')
    @page_title = @custom_product.name
  end

  def update
    @custom_product = current_user.custom_products.find(params[:id])

    if @custom_product.update(custom_product_params)
      flash[:notice] = I18n.t(
        'custom_products.updated',
        link: ActionController::Base.helpers.link_to(
          @custom_product.name,
          user_custom_product_path(id: @custom_product.id, user_id: current_user.user_name.downcase)
        )
      )
      redirect_to dashboard_custom_products_path
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @custom_product = current_user.custom_products.find(params[:id])
    @custom_product.destroy
    flash[:notice] = I18n.t('custom_products.deleted', name: @custom_product.name)
    redirect_to dashboard_custom_products_path
  end

  private

  def set_breadcrumb
    add_breadcrumb I18n.t('dashboard'), dashboard_root_path
    add_breadcrumb I18n.t('headings.custom_products'), dashboard_custom_products_path
    @active_dashboard_menu = :custom_products
    @active_menu = :dashboard
  end

  def custom_product_params
    params.require(:custom_product).permit(:name, :description, sub_category_ids: [])
  end

  def get_redirect_if_unauthorized(user, possession)
    return if user.visible?

    # if visited profile is not visible to logged out users and the current user is logged in
    return if user.logged_in_only? && user_signed_in?

    # if the visited profile is not visible to anyone and the visiting user is a different user
    return root_url if user.hidden? && current_user != user

    redir = user_custom_product_path(user_id: user.user_name.downcase, id: possession.id)
    new_user_session_url(redirect: URI.parse(redir).path)
  end
end
