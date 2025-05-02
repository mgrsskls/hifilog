ActiveAdmin.register ProductVariant do
  permit_params :product_id, :name, :description, :release_year, :release_month, :release_day, :price, :price_currency, :slug, :discontinued, :discontinued_year, :discontinued_month, :discontinued_day, :diy_kit

  menu parent: "Products"

  config.filters = false

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
