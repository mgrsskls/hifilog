# frozen_string_literal: true

# A shop's word can say two things at once.
#
# Shunyata Research writes "Archived Digital Cables": the products are digital
# cables, and they are no longer made. Totem has "Legacy Products", Thivan Labs
# has "Discontinued Product". Each of those is a statement about the product's
# state that a person knows and the markup does not carry -- an archived product
# is simply absent from the shop's availability fields.
#
# So a mapping decides up to three things now: which sub categories, whether the
# word is out of scope, and whether the products under it are discontinued.
# Three states, not two: nil says nothing and leaves whatever the shop stated,
# true and false overrule it, because a person deciding "archived means gone"
# knows more than an availability flag does.
class AddDiscontinuedToImportCategoryMappings < ActiveRecord::Migration[8.1]
  def change
    add_column :import_category_mappings, :discontinued, :boolean
  end
end
