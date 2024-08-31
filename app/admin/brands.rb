ActiveAdmin.register Brand do

  # See permitted parameters documentation:
  # https://github.com/activeadmin/activeadmin/blob/master/docs/2-resource-customization.md#setting-up-strong-parameters
  #
  # Uncomment all parameters which should be permitted for assignment
  #
  permit_params :name, :discontinued, :slug, :website, :country_code, :full_name
  #
  # or
  #
  # permit_params do
  #   permitted = [:name, :discontinued, :slug]
  #   permitted << :other if params[:action] == 'create' && current_user.admin?
  #   permitted
  # end

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
