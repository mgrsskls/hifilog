ActiveAdmin.register SetupPossession do
  controller do
    actions :all, except: [:show, :edit]
  end

  index do
    selectable_column
    id_column
    column :setup
    column :possession
    column ("Product") do |v|
      possession = Possession.find(v.possession_id)
      Product.find(possession.product_id) if possession.product_id.present?
    end
    column ("Product Variant") do |v|
      possession = Possession.find(v.possession_id)
      ProductVariant.find(possession.product_variant_id) if possession.product_variant_id.present?
    end
    column ("Custom Product") do |v|
      possession = Possession.find(v.possession_id)
      CustomProduct.find(possession.custom_product_id) if possession.custom_product_id.present?
    end
    column ("User") do |v|
      possession = Possession.find(v.possession_id)
      User.find(possession.user_id)
    end
    actions
  end
end
