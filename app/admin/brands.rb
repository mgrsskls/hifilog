ActiveAdmin.register Brand do
  permit_params :country_code, :description, :discontinued_day, :discontinued_month, :discontinued_year, :discontinued, :founded_day, :founded_month, :founded_year, :full_name, :name, :slug, :website

  remove_filter :description
  remove_filter :discontinued_day
  remove_filter :discontinued_month
  remove_filter :discontinued_year
  remove_filter :founded_day
  remove_filter :founded_month
  remove_filter :founded_year
  remove_filter :full_name
  remove_filter :products
  remove_filter :slug
  remove_filter :slugs
  remove_filter :versions
  remove_filter :website

  index do
    id_column
    column :name
    column :full_name
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

  sidebar :versionate, partial: "layouts/admin/version", only: :show
end
