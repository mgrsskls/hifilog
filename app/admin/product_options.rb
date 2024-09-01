ActiveAdmin.register ProductOption do
  permit_params :product_id, :product_variant_id, :option
end
