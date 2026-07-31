# frozen_string_literal: true

ActiveAdmin.register_page 'User Images' do
  menu parent: 'Users', label: 'Images', priority: 8

  content title: 'User Images' do
    rows = UserImagesQuery.call(page: params[:page])

    paginated_collection rows, download_links: false, entry_name: 'Image row' do
      table_for collection do
        column 'Type' do |row|
          case row.type
          when 'possession' then status_tag('Possession')
          when 'avatar' then status_tag('Avatar')
          when 'decorative_image' then status_tag('Decorative image')
          end
        end

        column :user do |row|
          link_to row.user.user_name, admin_user_path(row.user)
        end

        column 'Subject' do |row|
          case row.type
          when 'possession'
            possession = row.record
            name =
              if possession.custom_product.present?
                CustomProductPresenter.new(possession.custom_product).display_name
              elsif possession.product_variant.present?
                possession.product_variant.display_name
              else
                possession.product.display_name
              end
            link_to name, admin_possession_path(possession)
          when 'avatar'
            'Avatar'
          when 'decorative_image'
            'Decorative image'
          end
        end

        column 'Images' do |row|
          div class: 'flex flex-wrap gap-2 items-center' do
            row.images.each do |image|
              text_node image_tag(
                cdn_image_url(image.variant(:thumb)),
                alt: '',
                style: 'max-block-size: 3rem; max-inline-size: 3rem; object-fit: cover; border-radius: 0.25rem;'
              )
            end
          end
        end

        column 'Count' do |row|
          row.images.size
        end

        column 'Uploaded' do |row|
          uploaded_at = row.uploaded_at
          uploaded_at = Time.zone.parse(uploaded_at.to_s) if uploaded_at && !uploaded_at.respond_to?(:strftime)
          if uploaded_at
            "#{uploaded_at.strftime('%d.%m.%Y')}<br><small>#{uploaded_at.strftime('%H:%M')}</small>".html_safe
          end
        end
      end
    end
  end
end
