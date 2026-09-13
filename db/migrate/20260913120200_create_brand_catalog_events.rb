# frozen_string_literal: true

class CreateBrandCatalogEvents < ActiveRecord::Migration[8.1]
  def change
    create_view :brand_catalog_events
  end
end
