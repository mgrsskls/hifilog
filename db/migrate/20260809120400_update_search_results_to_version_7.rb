# frozen_string_literal: true

class UpdateSearchResultsToVersion7 < ActiveRecord::Migration[8.1]
  def change
    update_view :search_results, version: 7, revert_to_version: 6
  end
end
