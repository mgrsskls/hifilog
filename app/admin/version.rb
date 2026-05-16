ActiveAdmin.register PaperTrail::Version do
  menu parent: 'Data & Analytics', label: 'Product & Brand Activities', priority: 3

  actions :index, :show

  def controller
    def index
      column :id
      column :item_type
      column ("Item") do |v|
        if v.item_type == "Product"
          Product.find(v.item_id)
        elsif v.item_type == "Brand"
          Brand.find(v.item_id)
        end
      end
      column :event
      column ("User") do |v|
        v.whodunnit ? User.find(v.whodunnit) : "-"
      end
    end
  end
end
