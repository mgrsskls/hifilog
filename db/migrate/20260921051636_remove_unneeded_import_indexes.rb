class RemoveUnneededImportIndexes < ActiveRecord::Migration[8.1]
  def change
    remove_index :import_candidates, name: "index_import_candidates_on_brand_id", column: :brand_id
    remove_index :import_category_mappings, name: "index_import_category_mappings_on_brand_id", column: :brand_id
  end
end
