ActiveAdmin.register Brand do
  permit_params :country_code, :description, :discontinued_day, :discontinued_month, :discontinued_year, :discontinued, :founded_day, :founded_month, :founded_year, :full_name, :logo, :name, :remove_logo, :website, sub_category_ids: []

  menu priority: 2

  remove_filter :created_at
  remove_filter :updated_at
  remove_filter :description
  remove_filter :discontinued_day
  remove_filter :discontinued_month
  remove_filter :discontinued_year
  remove_filter :founded_day
  remove_filter :founded_month
  remove_filter :founded_year
  remove_filter :full_name
  remove_filter :pg_search_document
  remove_filter :products
  remove_filter :slug
  remove_filter :slugs
  remove_filter :versions
  remove_filter :website

  action_item :add_product, only: :show do
    link_to 'Add Product', new_admin_product_path(product: { brand_id: @brand.id }), class: 'action-item-button'
  end

  index do
    selectable_column
    id_column
    column "Name" do |brand|
      if brand.full_name.present?
        "#{brand.name}<small><br>#{brand.full_name}</small>".html_safe
      else
        brand.name
      end
    end
    column :discontinued
    column :logo do |brand|
      if brand.logo.attached?
        image_tag(cdn_image_url(brand.logo.variant(:thumb)), alt: "",
                  style: "max-block-size: 3rem; max-inline-size: 10rem; object-fit: contain;")
      end
    end
    column :website
    column :country_code
    column :products do |brand|
      brand.products.count
    end
    column :sub_categories do |brand|
      brand.sub_categories.count
    end
    actions
  end

  controller do
    def find_resource
      scoped_collection.friendly.find(params[:id])
    end

    def show
      @brand = Brand.includes(versions: :item).friendly.find(params[:id])
      @versions = @brand.versions
      @brand = @brand.versions[params[:version].to_i].reify if params[:version]
      show! #it seems to need this
    end
  end

  form html: { multipart: true } do |f|
    f.inputs do
      logo_hint =
        if f.object.logo.attached?
          image_tag(cdn_image_url(f.object.logo.variant(:thumb)),
                    alt: "", style: "max-block-size: 6rem; max-inline-size: 16rem; object-fit: contain; display: block; margin-block-end: 0.5rem;")
        end
      f.input :logo, as: :file,
                      hint: logo_hint,
                      input_html: { accept: "image/png,image/jpeg,image/jpg,image/gif,image/webp" }
      f.input :remove_logo, as: :boolean if f.object.logo.attached?
      f.input :name
      f.input :full_name
      f.input :website
      f.input :country_code
      f.li do
        f.ol class: "flex gap-4" do
          f.input :founded_year
          f.input :founded_month
          f.input :founded_day
        end
      end
      f.input :discontinued, as: :radio
      f.li do
        f.ol class: "flex gap-4" do
          f.input :discontinued_year
          f.input :discontinued_month
          f.input :discontinued_day
        end
      end
      f.input :description
      f.li class: "mb-4" do
        f.fieldset do
          f.legend class: "font-bold text-xl" do "Categories" end
          Category.all.each do |category|
            f.input :sub_category_ids, label: "<b>#{category.name}</b>".html_safe, as: :check_boxes, collection: category.sub_categories
          end
        end
      end
    end
    f.submit
  end

  sidebar :versionate, partial: "layouts/admin/version", only: :show
end
