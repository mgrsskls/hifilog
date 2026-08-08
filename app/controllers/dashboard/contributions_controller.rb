# frozen_string_literal: true

class Dashboard::ContributionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_menu

  def index
    page_title(I18n.t('headings.contributions'))
    @active_dashboard_menu = :contributions

    whodunnit = current_user.id

    products = Product.joins(:versions)
                      .distinct
                      .includes([:brand])
                      .select('products.*, versions.event')
                      .where(versions: { item_type: 'Product', whodunnit: })
    product_variants = ProductVariant.joins(:versions)
                                     .distinct
                                     .includes([{ product: [:brand] }])
                                     .select('product_variants.*, versions.event')
                                     .where(versions: { item_type: 'ProductVariant', whodunnit: })
    @items = (products + product_variants)
             .sort_by { |possession| possession.display_name.downcase }
             .group_by(&:event)
    @brands = Brand.joins(:versions)
                   .distinct
                   .select('brands.*, versions.event')
                   .where(versions: { item_type: 'Brand', whodunnit: })
                   .order(:name)
                   .group_by(&:event)
  end

  private

  def set_menu
    @active_menu = :dashboard
  end
end
