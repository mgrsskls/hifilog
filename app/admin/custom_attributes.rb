ActiveAdmin.register CustomAttribute do
  # option_scopes is { sub_category_id => [option ids] }, so its keys are ids rather than a
  # fixed list -- `{}` is how strong parameters permits a hash whose keys are not known ahead.
  permit_params :label, :highlighted, :input_type, :options_editor,
                units: [], inputs: [], sub_category_ids: [],
                options_attributes: [:key, :value],
                option_scopes: {}

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

      # Both live in the options group so they appear and disappear together with the input
      # type, and the scope matrix is built from the options directly above it.
      f.div "data-field-group": "options" do
        f.template.render(
          partial: "admin/custom_attributes/options_editor",
          locals: { custom_attribute: f.object }
        )
        f.template.render(
          partial: "admin/custom_attributes/option_scopes",
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

  # By label rather than by id: the list is read to find an attribute, not to see what was
  # created most recently.
  config.sort_order = "label_asc"

  scope :all, default: true
  scope("Key specs") { |scope| scope.where(highlighted: true) }
  scope("Options") { |scope| scope.where(input_type: %w[option options]) }
  scope("Measurements") { |scope| scope.where(input_type: "number") }

  controller do
    # Every row renders its categories and their parents, which is one query each without this.
    def scoped_collection
      super.includes(sub_categories: :category)
    end
  end

  index do
    selectable_column

    # The rendered name is what a contributor sees and the label is what products store; both
    # matter here, and a label with no translation is a bug that only shows up by looking.
    column "Attribute", sortable: :label do |custom_attribute|
      translated = t("custom_attribute_labels.#{custom_attribute.label}", default: nil)

      safe_join([
                  translated ? tag.b(translated) : tag.b("no translation", class: "text-red-600"),
                  tag.div(custom_attribute.label, class: "font-mono text-xs text-gray-500")
                ])
    end

    column :input_type
    column "Key spec", :highlighted

    # What the product form will actually render: the choices for an option type, the units and
    # fields for a measurement. A boolean has neither, and shows nothing.
    column "Configuration" do |custom_attribute|
      if custom_attribute.options.present?
        safe_join(custom_attribute.options.map { |id, key| "#{id}: #{t("custom_attributes.#{key}", default: key)}" },
                  tag.br)
      elsif custom_attribute.number_input_type?
        parts = []
        # Unit translations carry entities such as &ohm;, and are our own locale content.
        if custom_attribute.units.any?
          parts << "<b>Units:</b> #{custom_attribute.units.map do |unit|
            t("custom_attribute_units.#{unit}")
          end.join(' / ')}".html_safe
        end
        if custom_attribute.inputs.any?
          parts << "<b>Inputs:</b>".html_safe
          parts << "<ol class='ps-3 list-decimal list-inside'>#{
            custom_attribute.inputs.map do |input|
              "<li>#{t("custom_attribute_inputs.#{input}")}</li>"
            end.join
          }</ol>".html_safe
        end
        safe_join(parts, tag.br)
      end
    end

    # Grouped by parent category, and for an option type each category names the options it
    # actually offers -- a count alone says a category is narrowed without saying to what, which
    # is the thing worth checking from a list.
    #
    # Narrowed options are rendered in the definition's own order rather than the stored array's,
    # so the list reads the same here as on the product form.
    column "Applies to" do |custom_attribute|
      scopes = CustomAttribute.sub_category_scopes_cached.fetch(custom_attribute.id, {})
      options = custom_attribute.options || {}

      safe_join(
        custom_attribute.sub_categories.group_by { |sub_category| sub_category.category.name }.sort.map do |name, subs|
          rows = subs.sort_by(&:name).map do |sub_category|
            narrowed = scopes[sub_category.id].presence
            offered =
              if options.empty?
                nil
              elsif narrowed&.any?
                options.select { |id, _| narrowed.include?(id) }
                       .values
                       .map { |key| "<div class='ms-3'>#{t("custom_attributes.#{key}", default: key)}</div>" }
                       .join
                       .html_safe
              end

            tag.li(
              safe_join([
                tag.b(sub_category.name),
                tag.div(offered)
              ])
            )
          end

          tag.div(
            safe_join([
                        tag.div(name),
                        tag.ul(safe_join(rows), class: "mb-2 ml-3")
                      ])
          )
        end
      )
    end

    # Whether anyone has actually filled it in, which is the question the rollout keeps raising.
    column "Products" do |custom_attribute|
      @product_usage ||= CustomAttribute.product_usage_counts
      @product_usage[custom_attribute.label].to_i
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
