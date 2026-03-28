class FixRedundantIndexesAndForeignKeys < ActiveRecord::Migration[8.1]
  def change
    # Remove redundant single-column indexes covered by composite indexes
    remove_index :product_variants, name: "index_product_variants_product_id" if index_exists?(:product_variants, name: "index_product_variants_product_id")
    remove_index :product_options, name: "index_product_options_product_id" if index_exists?(:product_options, name: "index_product_options_product_id")
    remove_index :possessions, name: "index_possessions_user_id" if index_exists?(:possessions, name: "index_possessions_user_id")
    remove_index :notes, name: "index_notes_product_id" if index_exists?(:notes, name: "index_notes_product_id")
    
    # Add missing indexes on foreign keys
    add_index :product_options, :product_variant_id, name: "index_product_options_on_product_variant_id" unless index_exists?(:product_options, :product_variant_id)
    add_index :event_attendees, :event_id, name: "index_event_attendees_on_event_id" unless index_exists?(:event_attendees, :event_id)
    add_index :possessions, :custom_product_id, name: "index_possessions_on_custom_product_id" unless index_exists?(:possessions, :custom_product_id)
    add_index :possessions, [:custom_product_id, :user_id], name: "index_possessions_on_custom_product_id_and_user_id", unique: true unless index_exists?(:possessions, [:custom_product_id, :user_id])
    
    # Fix foreign key cascade for BookmarkList -> Bookmarks
    remove_foreign_key :bookmarks, :bookmark_lists if foreign_key_exists?(:bookmarks, :bookmark_lists)
    add_foreign_key :bookmarks, :bookmark_lists, on_delete: :nullify
  end
end
