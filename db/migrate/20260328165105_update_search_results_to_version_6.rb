class UpdateSearchResultsToVersion6 < ActiveRecord::Migration[8.1]
  def change
    update_view :search_results, version: 6, revert_to_version: 5
  end
end
