class AddCommentToVersions < ActiveRecord::Migration[7.1]
  def change
    add_column :versions, :comment, :text
  end
end
