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

  controller do
    def find_resource
      scoped_collection.friendly.find(params[:id])
    end
  end

  form do |f|
    f.inputs do
      f.has_many :sub_categories_id, new_record: false do |sub_category|
        sub_category.inputs "Photos" do
          sub_category.input :name
          #repeat as necessary for all fields
        end
      end
    end
  end
end
