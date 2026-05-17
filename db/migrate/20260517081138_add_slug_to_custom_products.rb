# frozen_string_literal: true

class AddSlugToCustomProducts < ActiveRecord::Migration[8.1]
  def up
    add_column :custom_products, :slug, :string

    CustomProduct.reset_column_information

    CustomProduct.find_each do |custom_product|
      next if custom_product.name.blank?

      base = custom_product.name.to_s.parameterize
      next if base.blank?

      candidate = base
      suffix = 1
      while CustomProduct.where(user_id: custom_product.user_id, slug: candidate)
                         .where.not(id: custom_product.id).exists?
        suffix += 1
        candidate = "#{base}-#{suffix}"
      end

      custom_product.update_columns(slug: candidate)
    end

    change_column_null :custom_products, :slug, false
    add_index :custom_products, %i[slug user_id], unique: true
  end

  def down
    remove_index :custom_products, column: %i[slug user_id]
    remove_column :custom_products, :slug
  end
end
