# frozen_string_literal: true

class AddSlugToSetups < ActiveRecord::Migration[8.1]
  def up
    add_column :setups, :slug, :string

    Setup.reset_column_information

    Setup.find_each do |setup|
      next if setup.name.blank?

      base = setup.name.to_s.parameterize
      next if base.blank?

      candidate = base
      suffix = 1
      while Setup.where(user_id: setup.user_id, slug: candidate).where.not(id: setup.id).exists?
        suffix += 1
        candidate = "#{base}-#{suffix}"
      end

      setup.update_columns(slug: candidate)
    end

    change_column_null :setups, :slug, false
    add_index :setups, %i[slug user_id], unique: true
  end

  def down
    remove_index :setups, column: %i[slug user_id]
    remove_column :setups, :slug
  end
end
