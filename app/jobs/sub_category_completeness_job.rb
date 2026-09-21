# frozen_string_literal: true

# Recalculates the completeness of all products in one sub category.
#
# A change to a highlighted custom attribute can change the score of all products in a sub
# category (see CustomAttribute). This job does that work outside of the web request.
#
# The job is continuable. After each product, it records the product id. When the dyno stops
# (deploy, daily restart), the job stops after the current product. Later, it continues after
# the last recorded id. It does not start again at the first product.
#
# Only one job for each sub category runs at a time. A second job for the same sub category
# waits until the first job is complete. It is not discarded, because the first job can have
# read the attribute definitions before the second change.
class SubCategoryCompletenessJob < ApplicationJob
  include ActiveJob::Continuable

  queue_as :default
  limits_concurrency key: ->(sub_category_id) { sub_category_id }, duration: 15.minutes

  def perform(sub_category_id)
    step :recalculate do |step|
      Product.recalculate_completeness_for_sub_category!(sub_category_id, start: step.cursor) do |product|
        step.advance! from: product.id
      end
    end
  end
end
