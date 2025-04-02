ActiveAdmin.register ProductVariant do
  permit_params [
    :product_id,
    :name,
    :description,
    :release_year,
    :release_month,
    :release_day,
    :price,
    :price_currency,
    :slug,
    :discontinued,
    :discontinued_year,
    :discontinued_month,
    :discontinued_day,
  ]

  remove_filter :description
  remove_filter :discontinued_day
  remove_filter :discontinued_month
  remove_filter :discontinued_year
  remove_filter :notes
  remove_filter :possessions
  remove_filter :price
  remove_filter :price_currency
  remove_filter :product_options
  remove_filter :release_day
  remove_filter :release_month
  remove_filter :release_year
  remove_filter :slug
  remove_filter :slugs
  remove_filter :users
  remove_filter :versions

  index do
    id_column
    column :name
    column :description
    column :price
    column :price_currency
    column :discontinued
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
