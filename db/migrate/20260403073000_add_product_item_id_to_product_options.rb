# frozen_string_literal: true

class AddProductItemIdToProductOptions < ActiveRecord::Migration[8.1]
  def change
    # ProductItem is backed by the `product_items` view whose primary key is a UUID
    # derived from either products.id or product_variants.id. Rails' default
    # has_many foreign key for `ProductItem has_many :product_options` is therefore
    # `product_options.product_item_id`.
    add_column :product_options, :product_item_id, :uuid

    add_index :product_options,
              :product_item_id,
              name: "index_product_options_on_product_item_id" unless index_exists?(:product_options, name: "index_product_options_on_product_item_id")

    # Backfill the derived UUID to make the association return correct records
    # for existing rows.
    reversible do |dir|
      dir.up do
        # Prefer the variant mapping when product_variant_id is present.
        execute <<-SQL.squish
          UPDATE product_options
          SET product_item_id = uuid_generate_v5(uuid_ns_dns(), ('variant-'::text || product_variant_id::text))
          WHERE product_variant_id IS NOT NULL;
        SQL

        execute <<-SQL.squish
          UPDATE product_options
          SET product_item_id = uuid_generate_v5(uuid_ns_dns(), ('product-'::text || product_id::text))
          WHERE product_variant_id IS NULL AND product_id IS NOT NULL;
        SQL
      end
    end

    remove_index :product_options, name: "index_product_options_on_product_id" if index_exists?(:product_options, name: "index_product_options_on_product_id")
  end
end

