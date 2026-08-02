ActiveAdmin.register ProductVariant do
  permit_params :product_id, :model_no, :name, :description, :release_year, :release_month, :release_day, :price, :price_currency, :discontinued, :discontinued_year, :discontinued_month, :discontinued_day, :diy_kit

  menu parent: "Products"

  config.filters = false

  action_item :convert_to_product, only: :show do
    link_to 'Convert to Product', convert_to_product_admin_product_variant_path(resource), class: 'action-item-button'
  end

  member_action :convert_to_product, method: [:get, :post] do
    if request.post?
      begin
        product = ProductConversionService.to_product(
          resource,
          sub_category_ids: params[:sub_category_ids],
          custom_attributes: (resource.product&.custom_attributes if params[:inherit_custom_attributes]),
          name: params[:product_name]
        )
        redirect_to admin_product_path(product), notice: "Converted to the product #{product.display_name}."
      rescue ProductConversionService::ConversionError => e
        redirect_to convert_to_product_admin_product_variant_path(resource), alert: e.message
      end
    else
      render 'active_admin/product_variants/convert_to_product'
    end
  end

  index do
    selectable_column
    id_column
    column :product do |product_variant|
      link_to "#{product_variant.product.brand.name} #{product_variant.product.name}", admin_product_path(product_variant.product)
    end
    column :name
    column :description
    column "Price", sortable: :price do |entity|
      "#{entity.price} #{entity.price_currency}"
    end
    column :discontinued
    column :diy_kit
    column :owned_by do |product_variant|
      product_variant.possessions.count
    end
    actions
  end

  controller do
    def find_resource
      scoped_collection.friendly.find(params[:id])
    end

    def show
      @product_variant = ProductVariant.includes(versions: :item).friendly.find(params[:id])
      @versions = @product_variant.versions
      @product_variant = @product_variant.versions[params[:version].to_i].reify if params[:version]
      show! #it seems to need this
    end
  end

  sidebar :versionate, partial: "layouts/admin/version", only: :show
end
