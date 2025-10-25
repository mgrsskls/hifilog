ActiveAdmin.register Bookmark do
  config.filters = false

  menu parent: "Users"

  index do
    selectable_column
    id_column
    column :user
    column "Product" do |bookmark|
      if bookmark.item_type == 'ProductVariant'
        ProductVariant.find(bookmark.item_id)
      else
        Product.find(bookmark.item_id)
      end
    end
    column "Created", sortable: :created_at do |entity|
      "#{entity.created_at&.strftime("%m.%d.%Y")}<br><small>#{entity.created_at&.strftime("%H:%M")}</small>".html_safe
    end
    column :bookmark_list
    actions
  end

  controller do
    actions :all, except: [:show, :edit]
  end
end
