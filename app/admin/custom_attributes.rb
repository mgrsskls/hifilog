ActiveAdmin.register CustomAttribute do
  permit_params :label, sub_category_ids: []

  form do |f|
    f.inputs do
      f.input :label
      f.input :sub_category_ids, label: "Subcategories", as: :check_boxes, collection: SubCategory.all
    end
    f.submit
  end
end
