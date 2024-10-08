ActiveAdmin.register Possession do
  permit_params [
    :user_id,
    :product_id,
    :product_variant_id,
    :custom_product_id,
    :product_option_id,
    :prev_owned,
    :period_from,
    :period_to
  ]

  remove_filter :custom_product
  remove_filter :image_attachment
  remove_filter :image_blob
  remove_filter :prev_owned
  remove_filter :product
  remove_filter :product_option
  remove_filter :product_variant
  remove_filter :setup
  remove_filter :setup_possession
end
