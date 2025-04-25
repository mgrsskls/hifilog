ActiveAdmin.register Bookmark do
  controller do
    actions :all, except: [:show, :edit]
  end

  remove_filter :product
  remove_filter :product_variant
  remove_filter :user
end
