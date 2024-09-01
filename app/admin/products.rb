ActiveAdmin.register Product do
  permit_params [
    :brand_id,
    :description,
    :discontinued_day,
    :discontinued_month,
    :discontinued_year,
    :discontinued,
    :discontinued,
    :name,
    :price_currency,
    :price,
    :release_day,
    :release_month,
    :release_year,
    :slug,
    sub_category_ids: [],
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
  remove_filter :product_variants
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
