# Product series (docs/product-series.md). "series" is uncountable, so the route helpers are
# admin_product_series_index_path (list) and admin_product_series_path(series) (one series).
ActiveAdmin.register ProductSeries do
  permit_params :brand_id, :name, :description

  menu parent: "Products", label: "Series"

  config.sort_order = 'name_asc'

  filter :brand, as: :select, collection: -> { Brand.order('LOWER(name)').pluck(:name, :id) }
  filter :name
  filter :products_count
  filter :created_at

  index do
    selectable_column
    id_column
    column :name
    column :brand
    column :products_count
    column :created_at
    column "Page" do |series|
      link_to "View", series.path, target: "_blank", rel: "noopener"
    end
    actions
  end

  show do
    attributes_table do
      row :name
      row :slug
      row :brand
      row :description
      row :products_count
      row :created_at
      row :updated_at
      row "Page" do |series|
        link_to series.path, series.path, target: "_blank", rel: "noopener"
      end
    end

    panel "Products" do
      table_for resource.products.order(:name) do
        column :id
        column :name do |product|
          link_to product.name, admin_product_path(product)
        end
        column :model_no
        column :release_year
      end
    end

    active_admin_comments_for(resource)
  end

  form do |f|
    f.semantic_errors
    f.inputs do
      # The brand can not change: the products of a series must have its brand.
      if f.object.new_record?
        f.input :brand, collection: Brand.order('LOWER(name)').pluck(:name, :id)
      else
        f.input :brand, input_html: { disabled: true }
      end
      f.input :name
      f.input :description
    end
    f.actions
  end

  controller do
    def show
      @product_series = ProductSeries.includes(versions: :item).find(params[:id])
      @versions = @product_series.versions
      @product_series = @product_series.versions[params[:version].to_i].reify if params[:version]
      show!
    end

    # The brand of a persisted series never changes (see the form).
    def update
      params[:product_series]&.delete(:brand_id)
      super
    end

    def destroy
      count = resource.products_count
      super do |success, _failure|
        success.html do
          redirect_to admin_product_series_index_path,
                      notice: "Series deleted. #{count} product(s) no longer have a series."
        end
      end
    end
  end

  sidebar :versionate, partial: "layouts/admin/version", only: :show
end
