class AddIndicesToImproveSearchPerformance < ActiveRecord::Migration[8.1]
  def change
    # Indexing Brands
    # We use gin_trgm_ops to enable fuzzy searching on name and full_name
    add_index :brands, :name, using: :gin, opclass: :gin_trgm_ops, name: 'index_brands_on_name_trgm'
    add_index :brands, :full_name, using: :gin, opclass: :gin_trgm_ops, name: 'index_brands_on_full_name_trgm'

    # Indexing Products
    add_index :products, :name, using: :gin, opclass: :gin_trgm_ops, name: 'index_products_on_name_trgm'
    add_index :products, :model_no, using: :gin, opclass: :gin_trgm_ops, name: 'index_products_on_model_no_trgm'

    # Indexing Product Variants
    add_index :product_variants, :name, using: :gin, opclass: :gin_trgm_ops, name: 'index_product_variants_on_name_trgm'
    add_index :product_variants, :model_no, using: :gin, opclass: :gin_trgm_ops, name: 'index_product_variants_on_model_no_trgm'

    add_index :brands, :created_at unless index_exists?(:brands, :created_at)

    # For Products
    execute <<-SQL
      CREATE INDEX index_products_on_search_uuid
      ON products (uuid_generate_v5(uuid_ns_dns(), 'product-' || id::text));
    SQL

    # For Variants
    execute <<-SQL
      CREATE INDEX index_variants_on_search_uuid
      ON product_variants (uuid_generate_v5(uuid_ns_dns(), 'variant-' || id::text));
    SQL

    # For Brands
    execute <<-SQL
      CREATE INDEX index_brands_on_search_uuid
      ON brands (uuid_generate_v5(uuid_ns_dns(), 'brand-' || id::text));
    SQL
  end
end
