class RenameImageToImages < ActiveRecord::Migration[8.0]
  def change
    ActiveStorage::Attachment.where(name: "image")
                             .where(record_type: "Possession")
                             .update(name: "images")
    ActiveStorage::Attachment.where(name: "image")
                             .where(record_type: "CustomProduct")
                             .update(name: "images")
  end
end
