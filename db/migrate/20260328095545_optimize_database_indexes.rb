class OptimizeDatabaseIndexes < ActiveRecord::Migration[8.1]
  def change
    # Products table optimizations
    remove_index :products, name: "index_products_on_discontinued" if index_exists?(:products, name: "index_products_on_discontinued")
    remove_index :products, name: "index_products_on_diy_kit" if index_exists?(:products, name: "index_products_on_diy_kit")
    
    add_index :products, [:brand_id, :discontinued], name: "index_products_on_brand_id_and_discontinued"
    add_index :products, [:brand_id, :diy_kit], name: "index_products_on_brand_id_and_diy_kit"
    
    # Product variants table optimizations
    add_index :product_variants, [:product_id, :discontinued], name: "index_product_variants_on_product_id_and_discontinued"
    add_index :product_variants, [:product_id, :diy_kit], name: "index_product_variants_on_product_id_and_diy_kit"
    
    # Foreign key indexes for better join performance
    add_index :product_options, [:product_id, :model_no], name: "index_product_options_on_product_id_and_model_no" unless index_exists?(:product_options, [:product_id, :model_no])
    add_index :notes, [:product_id, :user_id], name: "index_notes_on_product_id_and_user_id"
    add_index :possessions, [:user_id, :product_id], name: "index_possessions_on_user_id_and_product_id"
    add_index :possessions, [:user_id, :product_variant_id], name: "index_possessions_on_user_id_and_product_variant_id"
    
    # Bookmark optimization
    add_index :bookmarks, [:user_id, :bookmark_list_id], name: "index_bookmarks_on_user_id_and_bookmark_list_id"
    
    # Event attendees optimization
    add_index :event_attendees, [:event_id, :user_id], name: "index_event_attendees_on_event_id_and_user_id"
  end
end
