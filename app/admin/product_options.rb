ActiveAdmin.register ProductOption do
  permit_params :product_id, :product_variant_id, :option, :model_no

  menu parent: 'Settings'

  # An option is saved here without a save of its product or variant, so the changelog of the
  # product or variant gets its version here. See docs/catalog-model.md, "Changelog".
  before_save { |option| @versioned_owners = option.versioned_owners.each(&:remember_product_options) }
  after_save { |_option| @versioned_owners.each(&:record_product_options_version) }
  before_destroy { |option| @versioned_owners = option.versioned_owners.each(&:remember_product_options) }
  after_destroy { |_option| @versioned_owners.each(&:record_product_options_version) }

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
    column :model_no
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
