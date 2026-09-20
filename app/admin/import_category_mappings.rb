# frozen_string_literal: true

# The decisions that turn a shop's own word into a sub category of this
# catalogue, or refuse it.
#
# Made one time and applied by `rake import:map` to every run afterwards. This
# is what stops the same eleven thousand products being classified again after
# every crawl.
ActiveAdmin.register ImportCategoryMapping do
  menu parent: 'Import', priority: 2
  permit_params :brand_id, :source_category, :out_of_scope, :discontinued, sub_category_ids: []

  filter :brand
  filter :source_category
  filter :out_of_scope

  index do
    selectable_column
    column('Brand') { |mapping| mapping.brand&.name || 'any brand' }
    column :source_category
    column('This catalogue calls it') do |mapping|
      mapping.out_of_scope? ? status_tag('not a product here', class: 'warning') : sub_category_names_for(mapping).join(', ')
    end
    column('Candidates waiting') do |mapping|
      pending_count_for(mapping)
    end
    column('Discontinued') do |mapping|
      status_tag('discontinued', class: 'warning') unless mapping.discontinued.nil?
    end
    column :decided_by
    actions
  end

  form do |f|
    f.inputs do
      f.input :brand, include_blank: 'any brand',
                      hint: 'Leave empty when the word means the same for every shop.'
      f.input :source_category, hint: "The shop's own word, exactly as it writes it."
      f.input :sub_category_ids, as: :check_boxes,
              collection: SubCategory.order(:name).pluck(:name, :id),
              hint: 'More than one may be right: a shop that writes "In-Wall Subwoofers" means both, and so is a product that is both.'
      f.input :out_of_scope, label: 'This word names something the catalogue does not hold'
      f.input :discontinued, as: :select, include_blank: 'says nothing',
              collection: [['these are discontinued', true], ['these are current', false]],
              hint: 'For words like "Archived" or "Legacy", which state that the '\
                    'products under them are no longer made.'
    end
    f.actions
  end

  controller do
    def scoped_collection
      super.includes(:brand, :decided_by)
    end

    helper_method :sub_category_names_for, :pending_count_for

    def sub_category_names_for(mapping)
      sub_category_name_lookup[mapping.id] || []
    end

    def sub_category_name_lookup
      @sub_category_name_lookup ||= begin
        ids = collection.flat_map(&:sub_category_ids).uniq
        names = SubCategory.where(id: ids).order(:order, :name).pluck(:id, :name).to_h
        collection.index_by(&:id).transform_values do |mapping|
          mapping.sub_category_ids.filter_map { |id| names[id] }
        end
      end
    end

    # One query per grouping instead of one per row: a mapping either answers
    # a single brand's word, or every brand's, and the two counts are grouped
    # once for the whole page.
    def pending_count_for(mapping)
      if mapping.brand_id
        pending_counts_by_brand_and_category[[mapping.brand_id, mapping.source_category]].to_i
      else
        pending_counts_by_category[mapping.source_category].to_i
      end
    end

    def pending_counts_by_category
      @pending_counts_by_category ||= ImportCandidate.reviewable.group(:source_category).count
    end

    def pending_counts_by_brand_and_category
      @pending_counts_by_brand_and_category ||= begin
        brand_ids = collection.filter_map(&:brand_id).uniq
        ImportCandidate.reviewable.where(brand_id: brand_ids).group(:brand_id, :source_category).count
      end
    end

    def create
      # The mapping screen posts the same word more than once when a reviewer
      # goes back to it. Updating the existing decision is what they mean.
      attributes = permitted_params[:import_category_mapping]
      @import_category_mapping = ImportCategoryMapping.find_or_initialize_by(
        brand_id: attributes[:brand_id].presence,
        source_category: attributes[:source_category]
      )
      @import_category_mapping.assign_attributes(
        sub_category_ids: Array(attributes[:sub_category_ids]).compact_blank,
        out_of_scope: attributes[:out_of_scope] == '1',
        discontinued: attributes[:discontinued].presence,
        decided_by: current_admin_user
      )
      if @import_category_mapping.save
        redirect_back fallback_location: admin_import_category_mappings_path,
                      notice: "#{@import_category_mapping.source_category} decided. " \
                              'Run `rake import:map` to apply it.'
      else
        redirect_back fallback_location: admin_import_category_mappings_path,
                      alert: @import_category_mapping.errors.full_messages.to_sentence
      end
    end
  end
end
