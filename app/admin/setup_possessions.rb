ActiveAdmin.register SetupPossession do
  controller do
    actions :all, except: [:show, :edit]
  end

  remove_filter :possession

  index do
    selectable_column
    id_column
    column :setup
    column :possession
    column ("Product") do |v|
      possession = Possession.find(v.possession_id)

      if possession.custom_product_id.present?
        CustomProduct.find(possession.custom_product_id)
      elsif possession.product_variant_id.present?
        ProductVariant.find(possession.product_variant_id)
      else
        Product.find(possession.product_id)
      end
    end
    column ("User") do |v|
      possession = Possession.find(v.possession_id)
      User.find(possession.user_id)
    end
    actions
  end
end
