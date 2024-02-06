# frozen_string_literal: true
ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: proc { I18n.t("active_admin.dashboard") }

  content title: proc { I18n.t("active_admin.dashboard") } do
    section do
      h2 "Recently updated content"
      table_for PaperTrail::Version.order('id desc').limit(50) do
        column ("Item") { |v| v.item }
        column ("Type") { |v| v.item_type.underscore.humanize }
        column ("User") { |v| v.whodunnit ? (v.link_to User.find(v.whodunnit).email, [:admin, User.find(v.whodunnit)]) : "hifilog.com" }
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
