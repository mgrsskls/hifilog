# frozen_string_literal: true

class AddSlugAndCalendarYearToEvents < ActiveRecord::Migration[8.1]
  def up
    add_column :events, :slug, :string
    add_column :events, :calendar_year, :integer

    Event.reset_column_information

    Event.find_each do |e|
      next if e.start_date.blank? || e.name.blank?

      year = e.start_date.year
      base = e.name.to_s.parameterize
      next if base.blank?

      candidate = base
      suffix = 1
      while Event.where(calendar_year: year, slug: candidate).where.not(id: e.id).exists?
        suffix += 1
        candidate = "#{base}-#{suffix}"
      end

      e.update_columns(slug: candidate, calendar_year: year)
    end

    change_column_null :events, :slug, false
    change_column_null :events, :calendar_year, false
    add_index :events, %i[slug calendar_year], unique: true
  end

  def down
    remove_index :events, column: %i[slug calendar_year]
    remove_column :events, :slug
    remove_column :events, :calendar_year
  end
end
