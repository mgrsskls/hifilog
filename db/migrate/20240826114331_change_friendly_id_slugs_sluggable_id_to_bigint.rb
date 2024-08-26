class ChangeFriendlyIdSlugsSluggableIdToBigint < ActiveRecord::Migration[7.1]
  def change
    change_column :friendly_id_slugs, :sluggable_id, :bigint
  end
end
