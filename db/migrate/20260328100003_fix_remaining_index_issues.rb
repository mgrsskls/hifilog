class FixRemainingIndexIssues < ActiveRecord::Migration[8.1]
  def change
    # Remove redundant index covered by unique composite index
    remove_index :possessions, name: "index_possessions_on_custom_product_id" if index_exists?(:possessions, name: "index_possessions_on_custom_product_id")
    
    # Add index on product_id for ProductItem -> ProductOptions association
    add_index :product_options, :product_id, name: "index_product_options_on_product_id" unless index_exists?(:product_options, :product_id)
  end
end
