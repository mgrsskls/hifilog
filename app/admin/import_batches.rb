# frozen_string_literal: true

# One run of the importer, so that a set of candidates can be traced to when and
# from where it came -- and, if it went wrong, refused together.
ActiveAdmin.register ImportBatch do
  menu parent: 'Import', priority: 3
  actions :index, :show

  index do
    column :id
    column :source
    column :started_at
    column :finished_at
    column :candidates_count
    column('Still pending') do |batch|
      batch.import_candidates.reviewable.count
    end
    actions
  end

  show do
    attributes_table do
      row :source
      row :tool_version
      row :started_at
      row :finished_at
      row :candidates_count
      row :statistics
    end
  end
end
