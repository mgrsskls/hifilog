# frozen_string_literal: true

ActiveAdmin.register UserActivity do
  menu parent: 'Data & Analytics', priority: 2

  config.sort_order = 'occurred_at_desc'

  # A select with all users would load the full users table on each page view.
  filter :user_user_name, as: :string, label: 'User name'
  filter :verb, as: :select, label: 'Activity', collection: -> { UserActivity::VERBS.map { |verb| [verb.humanize, verb] } }
  filter :occurred_at
  filter :hidden_at

  index do
    # Loads everything the sentences need for this page with a fixed number of queries.
    AdminUserActivityPresenter.preload(collection)

    id_column
    column 'When', sortable: :occurred_at do |activity|
      admin_activity_timestamp(activity.occurred_at)
    end
    column 'Activity' do |activity|
      AdminUserActivityPresenter.new(activity, helpers).sentence
    end
    column 'Hidden', sortable: :hidden_at do |activity|
      status_tag('Hidden', title: "Hidden on #{activity.hidden_at.strftime('%d.%m.%Y %H:%M')}") if activity.hidden_at
    end
    actions
  end

  show do
    AdminUserActivityPresenter.preload([resource])

    attributes_table do
      row('Activity') { |activity| AdminUserActivityPresenter.new(activity, helpers).sentence }
      row :verb
      row :occurred_at
      row :hidden_at
      row :subject_type
      row :subject_id
      row(:metadata) { |activity| pre JSON.pretty_generate(activity.metadata || {}) }
      row :created_at
    end
  end
end
