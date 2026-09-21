# frozen_string_literal: true

# One-off backfill for AddCompletenessToProducts. Run once after that migration deploys; every
# write from then on keeps the columns in sync itself (see Product#recalculate_completeness!).
#
#   bin/rails completeness:backfill_products
namespace :completeness do
  desc 'Backfill products.completeness / specs_applicable / specs_filled for existing rows'
  task backfill_products: :environment do
    total = Product.count
    done = 0

    Product.find_each do |product|
      product.recalculate_completeness!
      done += 1
      print "\r#{done}/#{total}" if (done % 500).zero?
    end

    puts "\nDone: #{done} products."
  end
end
