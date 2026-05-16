ActiveAdmin.register_page 'PgHero' do
  menu parent: 'Data & Analytics', label: 'PgHero', priority: 999

  controller do
    layout 'active_admin_slim'  # This must be a layout in app/views/layouts

    def index
      render layout: 'active_admin_slim'
    end
  end

  content do
    render partial: 'active_admin/pg_hero'
  end
end
