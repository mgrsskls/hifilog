class CustomProductsController < ApplicationController
  before_action :authenticate_user!
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
    @possession = CustomProductPresenter.new(@user.possessions.find_by(custom_product_id: params[:id]))

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
        link: ActionController::Base.helpers.link_to(
          @custom_product.name,
          user_custom_product_path(id: @custom_product.id, user_id: current_user.user_name.downcase)
        )
      )
      redirect_to dashboard_custom_products_path
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
end
