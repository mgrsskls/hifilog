ActiveAdmin.register Possession do
  permit_params :user_id, :product_id, :product_variant_id, :custom_product_id, :product_option_id, :prev_owned, :period_from, :period_to, :gift, :price_purchase, :price_purchase_currency, :price_sale, :price_sale_currency, :purchase_condition

  config.filters = false

  menu parent: "Users"
  # menu priority: 0

  index do
    selectable_column
    id_column
    # Users write these names, so they go through safe_join and tag, which escape them
    # (docs/privacy-auth-security.md#3-security).
    column "Product" do |entity|
      name = if entity.custom_product.present?
               CustomProductPresenter.new(entity.custom_product).display_name
             elsif entity.product_variant.present?
               entity.product_variant.display_name
             else
               entity.product.display_name
             end
      next name if entity.product_option.blank?

      safe_join([name, tag.br, tag.small(entity.product_option.option)])
    end
    column :user
    column "Created", sortable: :created_at do |entity|
      "#{entity.created_at&.strftime("%m.%d.%Y")}<br><small>#{entity.created_at&.strftime("%H:%M")}</small>".html_safe
    end
    column "From", sortable: :period_from do |entity|
      entity.period_from&.strftime("%m.%d.%Y")
    end
    column "To", sortable: :period_to do |entity|
      entity.period_to&.strftime("%m.%d.%Y")
    end
    column "Purchase", sortable: :price_purchase do |entity|
      "#{entity.price_purchase} #{entity.price_purchase_currency}"
    end
    column "Sale", sortable: :price_sale do |entity|
      "#{entity.price_sale} #{entity.price_sale_currency}"
    end
    column :gift
    column :purchase_condition do |entity|
      entity.purchase_condition_label || '—'
    end
    column :prev_owned
    actions
  end
end
