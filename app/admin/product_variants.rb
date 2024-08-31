ActiveAdmin.register ProductVariant do
  # See permitted parameters documentation:
  # https://github.com/activeadmin/activeadmin/blob/master/docs/2-resource-customization.md#setting-up-strong-parameters
  #
  # Uncomment all parameters which should be permitted for assignment
  #
  permit_params :name, :product_id, :slug, :release_year, :release_month, :release_day, :price, :price_currency, :description
  #
  # or
  #
  # permit_params do
  #   permitted = [:name, :brand_id, :discontinued, :slug]
  #   permitted << :other if params[:action] == 'create' && current_user.admin?
  #   permitted
  # end

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

  form do |f|
    f.inputs do
      f.input :name
      f.input :slug
      f.input :product_id
      f.input :release_day
      f.input :release_month
      f.input :release_year
      f.input :price
      f.input :price_currency
      f.input :description
    end
    f.submit
  end

  show do
    attributes_table do
      row :name
      row :slug
      row :product
      row :updated_at
      row :release_year
      row :release_month
      row :release_day
      row :price
      row :price_currency
      row :description
    end

    active_admin_comments_for(resource)
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
