class ResetAllProductCountsOnBrands < ActiveRecord::Migration[7.1]
  def up
    Brand.all.each do |brand|
      Brand.reset_counters(brand.id, :products)
    end
  end

  def down
    # no rollback needed
  end
end
