# frozen_string_literal: true
ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: proc { I18n.t("active_admin.dashboard") }

  content title: proc { I18n.t("active_admin.dashboard") } do
    section do
      h2 "Recently updated content"
      table_for PaperTrail::Version.order('id desc').limit(50) do
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
        column :created_at
      end
    end

    # Here is an example of a simple dashboard with columns and panels.
    #
    # columns do
    #   column do
    #     panel "Recent Posts" do
    #       ul do
    #         Post.recent(5).map do |post|
    #           li link_to(post.title, admin_post_path(post))
    #         end
    #       end
    #     end
    #   end

    #   column do
    #     panel "Info" do
    #       para "Welcome to ActiveAdmin."
    #     end
    #   end
    # end
  end # content
end
