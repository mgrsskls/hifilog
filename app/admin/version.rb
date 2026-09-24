# frozen_string_literal: true

ActiveAdmin.register PaperTrail::Version do
  menu parent: 'Data & Analytics', label: 'Product & Brand Activities', priority: 3

  actions :index, :show

  config.sort_order = 'created_at_desc'

  # Explicit filters replace the default ones. The default ones include text searches on the
  # serialized object and object_changes columns, which scan the full table.
  filter :item_type, as: :select, label: 'Type',
                     collection: -> { AdminVersionActivityPresenter::ITEM_LABELS.map { |type, label| [label.capitalize, type] } }
  filter :event, as: :select, collection: -> { AdminVersionActivityPresenter::EVENT_VERBS.map { |event, verb| [verb.capitalize, event] } }
  filter :item_id, label: 'Item ID'
  filter :whodunnit, as: :string, label: 'User ID', filters: [:eq]
  filter :created_at

  index title: 'Product & Brand Activities' do
    # Loads everything the sentences and changes need for this page with a fixed number of queries.
    context = AdminVersionActivityPresenter.preload(collection)

    id_column
    column 'When', sortable: :created_at do |version|
      admin_activity_timestamp(version.created_at)
    end
    column 'Activity' do |version|
      AdminVersionActivityPresenter.new(version, helpers, context).sentence
    end
    column 'Changes' do |version|
      AdminVersionActivityPresenter.new(version, helpers, context).changes_list(truncate: 120)
    end
    column 'Comment' do |version|
      version.comment.to_s.truncate(120)
    end
    actions
  end

  show title: ->(version) { "#{version.item_type} ##{version.item_id}, version #{version.id}" } do
    context = AdminVersionActivityPresenter.preload([resource])
    presenter = AdminVersionActivityPresenter.new(resource, helpers, context)

    attributes_table do
      row('Activity') { presenter.sentence }
      row('When') { |version| version.created_at.strftime('%d.%m.%Y %H:%M') }
      row(:comment) { |version| simple_format(version.comment) if version.comment.present? }
    end

    panel 'Changes' do
      changes = presenter.changes
      if changes.empty?
        para 'No visible changes.'
      else
        table_for changes do
          column('Attribute') { |change| strong change.label }
          column('Before') { |change| change.before ? helpers.tag.del(change.before, class: 'AdminActivityChanges-before') : '–' }
          column('After') { |change| change.after ? helpers.tag.ins(change.after, class: 'AdminActivityChanges-after') : '–' }
        end
      end
    end
  end
end
