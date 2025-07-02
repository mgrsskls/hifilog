ActiveAdmin.register CustomAttribute do
  permit_params :options, :label, :input_type, units: [], inputs: [], sub_category_ids: []

  config.filters = false

  menu parent: "Settings"

  form do |f|
    f.inputs do
      f.input :label
      f.inputs do
        f.input :input_type, as: :radio, collection: CustomAttribute.input_types.keys
      end
      f.input :options, input_html: {
        value: f.object.options&.to_json,  # ← forces JSON format
        rows: 1,
        style: 'font-family: monospace;'
      }
      f.inputs do
        f.input :units, as: :check_boxes, collection: CustomAttribute::VALID_UNITS
      end
      f.inputs do
        f.input :inputs, as: :check_boxes, collection: CustomAttribute::VALID_INPUTS
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
end
