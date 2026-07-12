# frozen_string_literal: true

ActiveAdmin.register UserFollow do
  menu parent: 'Users'

  config.sort_order = 'created_at_desc'

  index do
    selectable_column
    id_column
    column :follower
    column :followed
    column 'Created', sortable: :created_at do |follow|
      "#{follow.created_at.strftime('%d.%m.%Y')}<br><small>#{follow.created_at.strftime('%H:%M')}</small>".html_safe
    end
    actions
  end

  filter :follower
  filter :followed
  filter :created_at

  controller do
    actions :all, except: %i[new create edit update]
  end
end
