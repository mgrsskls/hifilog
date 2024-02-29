ActiveAdmin.register Product do
  # See permitted parameters documentation:
  # https://github.com/activeadmin/activeadmin/blob/master/docs/2-resource-customization.md#setting-up-strong-parameters
  #
  # Uncomment all parameters which should be permitted for assignment
  #
  permit_params :name, :brand_id, :discontinued, :slug, sub_category_ids: []
  #
  # or
  #
  # permit_params do
  #   permitted = [:name, :brand_id, :discontinued, :slug]
  #   permitted << :other if params[:action] == 'create' && current_user.admin?
  #   permitted
  # end

  form do |f|
    f.inputs do
      f.input :name
      f.input :brand
      f.input :release_day
      f.input :release_month
      f.input :release_year
      f.input :discontinued
      f.input :discontinued_day
      f.input :discontinued_month
      f.input :discontinued_year
      f.input :price
      f.input :price_currency
      f.input :slug
      f.input :description
      f.input :sub_category_ids, label: "Subcategories", as: :check_boxes, collection: SubCategory.all
    end
    f.submit
  end

  show do
    attributes_table do
      row :name
      row :created_at
      row :updated_at
      row :brand
      row :discontinued
      row :description
      row :slug
      row :sub_categories do |product|
        product.sub_categories
      end
    end

    active_admin_comments_for(resource)
  end

  controller do
    def find_resource
      scoped_collection.friendly.find(params[:id])
    end

    def show
      @product = Product.includes(versions: :item).friendly.find(params[:id])
      @versions = @product.versions
      @product = @product.versions[params[:version].to_i].reify if params[:version]
      show! #it seems to need this
    end
  end

  sidebar :versionate, partial: "layouts/admin/version", only: :show
end
