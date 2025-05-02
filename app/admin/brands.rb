ActiveAdmin.register Brand do
  permit_params :country_code, :description, :discontinued_day, :discontinued_month, :discontinued_year, :discontinued, :founded_day, :founded_month, :founded_year, :full_name, :name, :slug, :website, sub_category_ids: []

  remove_filter :created_at
  remove_filter :updated_at
  remove_filter :description
  remove_filter :discontinued_day
  remove_filter :discontinued_month
  remove_filter :discontinued_year
  remove_filter :founded_day
  remove_filter :founded_month
  remove_filter :founded_year
  remove_filter :full_name
  remove_filter :pg_search_document
  remove_filter :products
  remove_filter :slug
  remove_filter :slugs
  remove_filter :versions
  remove_filter :website

  index do
    selectable_column
    id_column
    column "Name" do |brand|
      if brand.full_name.present?
        "#{brand.name}<small><br>#{brand.full_name}</small>".html_safe
      else
        brand.name
      end
    end
    column :discontinued
    column :website
    column :country_code
    column :products do |brand|
      brand.products.count
    end
    column :sub_categories do |brand|
      brand.sub_categories.count
    end
    actions
  end

  controller do
    def find_resource
      scoped_collection.friendly.find(params[:id])
    end

    def show
      @brand = Brand.includes(versions: :item).friendly.find(params[:id])
      @versions = @brand.versions
      @brand = @brand.versions[params[:version].to_i].reify if params[:version]
      show! #it seems to need this
    end
  end

  form do |f|
    f.inputs do
      f.input :name
      f.input :slug
      f.input :full_name
      f.input :website
      f.input :country_code
      f.li do
        f.ol class: "flex gap-4" do
          f.input :founded_year
          f.input :founded_month
          f.input :founded_day
        end
      end
      f.input :discontinued
      f.li do
        f.ol class: "flex gap-4" do
          f.input :discontinued_year
          f.input :discontinued_month
          f.input :discontinued_day
        end
      end
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

  sidebar :versionate, partial: "layouts/admin/version", only: :show
end
