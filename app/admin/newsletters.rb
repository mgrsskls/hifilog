ActiveAdmin.register Newsletter do
  permit_params :content

  config.filters = false

  after_create do |newsletter|
    recipients = User.where(receives_newsletter: true)

    recipients.each do |recipient|
      UserMailer.newsletter_email(
        recipient,
        newsletter.content
      ).deliver
    end
  end

  index do
    id_column
    column :content
    column "Created", sortable: :created_at do |entity|
      "#{entity.created_at.strftime("%m.%d.%Y")}<br><small>#{entity.created_at.strftime("%H:%M")}</small>".html_safe
    end
    actions
  end
end
