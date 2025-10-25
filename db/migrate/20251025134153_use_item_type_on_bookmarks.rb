class UseItemTypeOnBookmarks < ActiveRecord::Migration[7.1]
  def up
    # 1. Add new polymorphic columns
    add_column :bookmarks, :item_id, :bigint
    add_column :bookmarks, :item_type, :string

    # 2. Backfill data
    say_with_time "Backfilling item_id and item_type from product_id and product_variant_id" do
      Bookmark.reset_column_information

      Bookmark.find_each do |bookmark|
        if bookmark.product_variant_id.present?
          bookmark.update_columns(item_id: bookmark.product_variant_id, item_type: "ProductVariant")
        else
          bookmark.update_columns(item_id: bookmark.product_id, item_type: "Product")
        end
      end
    end

    # 3. Remove old columns
    remove_index :bookmarks, name: "idx_on_product_id_user_id_product_variant_id_24cc95bae4"
    remove_column :bookmarks, :product_id
    remove_column :bookmarks, :product_variant_id

    # 4. Add new index for uniqueness (item_id + item_type + user_id)
    add_index :bookmarks, [:user_id, :item_type, :item_id],
              unique: true,
              name: "index_bookmarks_on_user_item_type_and_item_id"
  end

  def down
    # 1. Recreate old columns
    add_column :bookmarks, :product_id, :bigint, null: false
    add_column :bookmarks, :product_variant_id, :bigint

    # 2. Backfill data from polymorphic columns
    say_with_time "Restoring product_id and product_variant_id from item_id/item_type" do
      Bookmark.reset_column_information

      Bookmark.find_each do |bookmark|
        case bookmark.item_type
        when "Product"
          bookmark.update_columns(product_id: bookmark.item_id)
        when "ProductVariant"
          bookmark.update_columns(product_id: nil, product_variant_id: bookmark.item_id)
        end
      end
    end

    # 3. Remove new columns and indexes
    remove_index :bookmarks, name: "index_bookmarks_on_user_item_type_and_item_id"
    remove_column :bookmarks, :item_id
    remove_column :bookmarks, :item_type

    # 4. Restore old unique index
    add_index :bookmarks, [:product_id, :user_id, :product_variant_id],
              unique: true,
              name: "idx_on_product_id_user_id_product_variant_id_24cc95bae4"
  end
end
