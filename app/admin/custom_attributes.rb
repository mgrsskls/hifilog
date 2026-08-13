ActiveAdmin.register CustomAttribute do
  permit_params :label, :highlighted, :input_type, :options_editor,
                units: [], inputs: [], sub_category_ids: [],
                options_attributes: [:key, :value]

  config.filters = false

  menu parent: "Settings"

  form do |f|
    f.inputs do
      f.input :label
      f.input :highlighted
      f.inputs do
        f.input :input_type, as: :radio, collection: CustomAttribute.input_types.keys
      end

      # Filled in by JS, and only while the pending input type would discard something.
      f.div "", "data-input-type-warning": "", class: "mb-4 text-sm font-bold", hidden: true

      f.div "data-field-group": "options" do
        f.template.render(
          partial: "admin/custom_attributes/options_editor",
          locals: { custom_attribute: f.object }
        )
      end

      f.div "data-field-group": "measurement" do
        f.inputs do
          f.input :units, as: :check_boxes, collection: CustomAttribute::VALID_UNITS
        end
        f.inputs do
          f.input :inputs, as: :check_boxes, collection: CustomAttribute::VALID_INPUTS
        end
      end

      f.div class: "mb-8" do
        f.fieldset do
          f.legend class: "font-bold text-xl" do "Categories" end
          Category.all.each do |category|
            f.input :sub_category_ids, label: "<b>#{category.name}</b>".html_safe, as: :check_boxes, collection: category.sub_categories
          end
        end
      end
    end
    f.submit
  end

  index do
    selectable_column
    column :id
    column :label
    column :input_type
    column :highlighted
    column "Options" do |custom_attribute|
      next unless custom_attribute.options.present?

      safe_join(custom_attribute.options.map { |id, key| "#{id}: #{t("custom_attributes.#{key}", default: key)}" }, tag.br)
    end
    column :sub_categories do |custom_attribute|
      custom_attribute.sub_categories.map(&:name).join(", ")
    end
    actions
  end

  show do
    attributes_table do
      row :label
      row :input_type
      row :highlighted
      row "Options" do |custom_attribute|
        next unless custom_attribute.options.present?

        usage = custom_attribute.option_usage_counts

        table do
          thead do
            tr do
              th "ID"
              th "Key"
              th "Label"
              th "Products"
            end
          end
          tbody do
            custom_attribute.options.each do |id, key|
              tr do
                td id
                td key
                td t("custom_attributes.#{key}", default: "(no translation)")
                td usage[id.to_s].to_i
              end
            end
          end
        end
      end
      row :units
      row :inputs
      row :sub_categories do |custom_attribute|
        custom_attribute.sub_categories.map(&:name).join(", ")
      end
    end

    active_admin_comments_for(resource)
  end

  controller do
    # `permit_params` above defines `permitted_params` directly on this controller
    # class, so a plain `def permitted_params` here would overwrite it rather than
    # sit above it — `super` would then skip straight to InheritedResources'
    # fallback, which returns nil. Prepending keeps it in the ancestor chain.
    module OptionsEditorParams
      # Browsers post nothing at all for a list the admin emptied, which is
      # indistinguishable from "this form never had an options field" — and would leave
      # the old options in place. The editor always posts a marker, so an emptied list
      # arrives here as an explicit empty set instead of as silence.
      def permitted_params
        super.tap do |params|
          attributes = params[:custom_attribute]
          next if attributes.blank?

          marker = attributes.delete(:options_editor)
          attributes[:options_attributes] ||= [] if marker.present?
        end
      end
    end
    prepend OptionsEditorParams
  end
end
