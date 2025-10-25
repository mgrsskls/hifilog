class UpdateSearchResultsToVersion5 < ActiveRecord::Migration[8.0]
  def change
    update_view :search_results, version: 5, revert_to_version: 4
  end
end
