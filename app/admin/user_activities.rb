ActiveAdmin.register UserActivity do
  menu parent: 'Data & Analytics', priority: 2

  config.sort_order = "occurred_at_desc"
end