# frozen_string_literal: true

ActiveAdmin.register UserBlock do
  menu parent: 'Users'

  config.sort_order = 'created_at_desc'

  index do
    selectable_column
    id_column
    column :blocker
    column :blocked
    column 'Created', sortable: :created_at do |block|
      "#{block.created_at.strftime('%d.%m.%Y')}<br><small>#{block.created_at.strftime('%H:%M')}</small>".html_safe
    end
    actions
  end

  filter :blocker
  filter :blocked
  filter :created_at

  controller do
    actions :all, except: %i[new create edit update]
  end
end
