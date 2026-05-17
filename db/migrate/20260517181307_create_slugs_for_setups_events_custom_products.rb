class CreateSlugsForSetupsEventsCustomProducts < ActiveRecord::Migration[8.1]
  def change
    Setup.transaction do
      Setup.find_each do |setup|
        setup.slug = nil
        setup.save!
        setup.slugs.update_all :scope => setup.serialized_scope
      end
    end
    Event.transaction do
      Event.find_each do |event|
        event.slug = nil
        event.save!
        event.slugs.update_all :scope => event.serialized_scope
      end
    end
    CustomProduct.transaction do
      CustomProduct.find_each do |custom_product|
        custom_product.slug = nil
        custom_product.save!
        custom_product.slugs.update_all :scope => custom_product.serialized_scope
      end
    end
  end
end
