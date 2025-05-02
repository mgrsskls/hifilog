ActiveAdmin.register ProductOption do
  permit_params :product_id, :product_variant_id, :option

  menu parent: 'Settings'

  index do
    selectable_column
    id_column
    column "Product" do |note|
      if note.product_variant.present?
        note.product_variant
      else
        note.product
      end
    end
    column :option
    column "Created", sortable: :created_at do |entity|
      "#{entity.created_at&.strftime("%m.%d.%Y")}<br><small>#{entity.created_at&.strftime("%H:%M")}</small>".html_safe
    end
    column "Updated", sortable: :updated_at do |entity|
      "#{entity.updated_at.strftime("%m.%d.%Y")}<br><small>#{entity.updated_at.strftime("%H:%M")}</small>".html_safe
    end
    column :user
    actions
  end
end
