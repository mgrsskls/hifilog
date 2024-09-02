# frozen_string_literal: true
ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: proc { I18n.t("active_admin.dashboard") }

  content title: proc { I18n.t("active_admin.dashboard") } do
    section do
      h2 "Recently updated content"
      table_for PaperTrail::Version.where.not(event: :destroy).order('id desc').limit(50) do
        column :id
        column :item_type
        column ("Item") do |v|
          if v.item_type == "Product"
            Product.where(id: v.item_id).last || "deleted"
          elsif v.item_type == "Brand"
            Brand.where(id: v.item_id).last || "deleted"
          end
        end
        column :event
        column ("User") do |v|
          v.whodunnit ? User.find(v.whodunnit) : "-"
        end
        column :created_at
      end
    end
  end
end
