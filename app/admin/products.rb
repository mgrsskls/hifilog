ActiveAdmin.register Product do
  belongs_to :brand, optional: true

  permit_params :name, :brand_id
end
