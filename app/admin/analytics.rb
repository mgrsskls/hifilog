ActiveAdmin.register_page 'Analytics' do
  menu parent: 'Data & Analytics', label: 'Analytics', priority: 1

  controller do
    layout 'active_admin_slim'  # This must be a layout in app/views/layouts

    def index
      render layout: 'active_admin_slim'
    end
  end

  content do
    render partial: 'active_admin/analytics'
  end
end
