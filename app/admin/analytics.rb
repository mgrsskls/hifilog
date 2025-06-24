ActiveAdmin.register_page 'Analytics' do
  menu priority: -1, label: 'Analytics'

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
