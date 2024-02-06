ActiveAdmin.register PaperTrail::Version do
  actions :index, :show

  index do
    column :id
    column :item_type
    column :item_id
    column :event
    column :user_type
    column("User Id") { |v| v.whodunnit }
  end
end
