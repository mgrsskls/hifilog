# frozen_string_literal: true

# An ActiveAdmin index as a grid of cards, one card per record.
#
# ActiveAdmin 4 has only the table index. A table with many columns is wide,
# and a reviewer then scrolls sideways to see one row. A card shows every field
# of one record in one place.
#
# Use it with a block that renders the content of one card:
#
#   index as: IndexAsGrid, sort_by: { score: 'Score', name: 'Name' } do |record|
#     field('Model') { record.model_no }
#   end
#
# The component writes the batch selection check box on each card, and a
# "select all" check box and the sort links above the grid. The check boxes
# have the classes of ActiveAdmin's own, so the batch actions work unchanged.
class IndexAsGrid < ActiveAdmin::Component
  def self.index_name
    'grid'
  end

  def build(page_presenter, collection)
    add_class 'index-as-grid'
    selectable = active_admin_config.batch_actions.any?

    div class: 'flex flex-wrap items-center gap-x-4 gap-y-2 mb-4 text-sm' do
      resource_selection_toggle_cell('Select all on this page') if selectable
      build_sort_links(page_presenter[:sort_by] || {})
    end

    div class: 'grid grid-cols-1 gap-4 md:grid-cols-2 2xl:grid-cols-3' do
      collection.each do |resource|
        article id: "grid_item_#{resource.id}",
                class: 'flex flex-col gap-3 rounded-lg border border-gray-200 bg-white p-4 ' \
                       'dark:border-gray-700 dark:bg-gray-900 ' \
                       'has-[.batch-actions-resource-selection:checked]:border-blue-600' do
          if selectable
            div class: 'flex items-center gap-2 text-sm' do
              resource_selection_cell resource
              label 'Select', for: "batch_action_item_#{resource.id}"
            end
          end
          instance_exec(resource, &page_presenter.block)
        end
      end
    end
  end

  # One labelled value in a card. Every field is written, also an empty one,
  # so that each card has the same fields in the same places, and a missing
  # value is seen at once. An empty value shows a dash.
  def field(label_text, value = nil, &block)
    div class: 'min-w-0' do
      div label_text, class: 'text-xs uppercase tracking-wide text-gray-500 dark:text-gray-400'
      div class: 'break-words text-sm' do
        result = block ? yield : value
        if result.is_a?(Arbre::Element)
          # The block built its own content.
        elsif result.blank? && result != false
          span '—', class: 'text-gray-400 dark:text-gray-500', 'aria-label': 'not stated'
        else
          text_node result.to_s
        end
      end
    end
  end

  private

  # The table sorts by a click on a column header. A grid has no header, so
  # the columns to sort by are links. A second click on the current order
  # reverses it. The order parameter has ActiveAdmin's own form, "score_desc".
  def build_sort_links(options)
    return if options.empty?

    current = params[:order].to_s
    span 'Sort by:', class: 'text-gray-500 dark:text-gray-400'
    options.each do |attribute, title|
      descending = "#{attribute}_desc"
      active = [descending, "#{attribute}_asc"].include?(current)
      target = current == descending ? "#{attribute}_asc" : descending
      arrow = if current == descending then ' ↓'
              elsif current == "#{attribute}_asc" then ' ↑'
              else ''
              end
      a "#{title}#{arrow}",
        href: url_for(request.query_parameters.merge('order' => target, 'page' => nil).compact),
        class: active ? 'font-bold' : ''
    end
  end
end
