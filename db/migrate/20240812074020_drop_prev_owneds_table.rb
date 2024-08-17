class DropPrevOwnedsTable < ActiveRecord::Migration[7.1]
  def change
    Possession.all.update_all(prev_owned: false)
    PrevOwned.all.each do |prev|
      Possession.create(
        product_id: prev.product_id,
        user_id: prev.user_id,
        product_variant_id: prev.product_variant_id,
        custom_product_id: prev.custom_product_id,
        prev_owned: true
      )
    end

    drop_table :prev_owneds
  end
end
