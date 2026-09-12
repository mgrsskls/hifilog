# frozen_string_literal: true

# A stable identifier for a sub category, separate from its URL slug.
#
# `slug` is derived from `name` and FriendlyId regenerates it whenever the name changes
# (SubCategory#should_generate_new_friendly_id?). That is correct for a URL, and wrong for an
# identifier: RelatedProducts::Graph references sub categories by name-derived slug, so renaming
# "Bookshelf & Standmount Loudspeakers" for clarity silently emptied every pairing edge touching
# it. Identity and URL are different concerns; this splits them.
#
# Backfilled from the current slug verbatim, so the graph's declarations keep resolving unchanged.
class AddIdentifierToSubCategories < ActiveRecord::Migration[8.1]
  def up
    add_column :sub_categories, :identifier, :citext
    execute 'UPDATE sub_categories SET identifier = slug'
    change_column_null :sub_categories, :identifier, false
    add_index :sub_categories, :identifier, unique: true
  end

  def down
    remove_index :sub_categories, :identifier
    remove_column :sub_categories, :identifier
  end
end
