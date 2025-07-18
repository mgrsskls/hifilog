ActiveAdmin.register Product do
  permit_params :brand_id, :description, :discontinued_day, :discontinued_month, :discontinued_year, :discontinued, :discontinued, :diy_kit, :name, :model_no, :price_currency, :price, :release_day, :release_month, :release_year, sub_category_ids: []

  menu priority: 3

  remove_filter :created_at
  remove_filter :updated_at
  remove_filter :description
  remove_filter :discontinued_day
  remove_filter :discontinued_month
  remove_filter :discontinued_year
  remove_filter :notes
  remove_filter :possessions
  remove_filter :pg_search_document
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

  action_item :add_variant, only: :show do
    link_to 'Add Variant', new_admin_product_variant_path(product_variant: { product_id: @product.id }), class: 'action-item-button'
  end

  form do |f|
    f.inputs do
      f.input :name
      f.input :model_no
      f.input :brand
      f.input :release_day
      f.input :release_month
      f.input :release_year
      f.input :discontinued
      f.input :discontinued_day
      f.input :discontinued_month
      f.input :discontinued_year
      f.input :diy_kit
      f.input :price
      f.input :price_currency
      f.input :description
      f.li class: "mb-4" do
        f.fieldset do
          f.legend class: "font-bold text-xl" do "Categories" end
          Category.all.each do |category|
            f.input :sub_category_ids, label: "<b>#{category.name}</b>".html_safe, as: :check_boxes, collection: category.sub_categories
          end
        end
      end
    end
    f.submit
  end

  show do
    attributes_table do
      row :name
      row :model_no
      row :created_at
      row :updated_at
      row :brand
      row :discontinued
      row :diy_kit
      row :description
      row :slug
      row :sub_categories do |product|
        product.sub_categories
      end
    end

    active_admin_comments_for(resource)
  end

  index do
    selectable_column
    id_column
    column :name
    column :model_no
    column :brand
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
      @product = Product.includes(versions: :item).friendly.find(params[:id])
      @versions = @product.versions
      @product = @product.versions[params[:version].to_i].reify if params[:version]
      show! #it seems to need this
    end
  end

  sidebar :versionate, partial: "layouts/admin/version", only: :show
end
