ActiveAdmin.register Note do
  permit_params :product_id, :product_variant_id, :user_id, :text

  remove_filter :product
  remove_filter :product_variant
end
