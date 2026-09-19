# frozen_string_literal: true

# Tasks for product series (docs/product-series.md, "Existing data").
#
#   bin/rails series:candidates                         # read-only: possible series per brand
#   bin/rails series:candidates[fezz-audio]             # the same, for one brand
#   bin/rails "series:apply[fezz-audio,Evolution]"      # dry run: what the task would change
#   bin/rails "series:apply[fezz-audio,Evolution,run]"  # change the data
#   bin/rails series:duplicates                         # read-only: same brand + name + model no.
#   bin/rails series:resync_slugs                       # make the slugs of products in a series again
#
# Some products have the series name in the product name, for example "Evolution Omega Lupi" by
# Fezz Audio. series:apply moves the name into a series: it creates the series if necessary,
# removes the series name from the start of the product name and assigns the series. The slug
# is brand + series + name, so it does not change and no redirect is necessary.
#
# Never apply a series without examining the candidates first: a model name can start with a
# word that is not a series.
namespace :series do
  desc 'List words that start the names of two or more products of one brand (read-only)'
  task :candidates, [:brand_slug] => :environment do |_task, args|
    brands = args[:brand_slug].present? ? Brand.where(slug: args[:brand_slug]) : Brand.all

    brands.find_each do |brand|
      groups = brand.products.where(product_series_id: nil).pluck(:id, :name)
                    .group_by { |_id, name| name.to_s.split.first.to_s.downcase }
                    .select do |word, rows|
                      word.present? && rows.size >= 2 && rows.any? { |_id, name| name.split.size > 1 }
                    end
      next if groups.empty?

      puts "#{brand.display_name} (#{brand.slug})"
      groups.sort.each do |word, rows|
        puts "  #{word}: #{rows.map(&:last).sort.join(' | ')}"
      end
    end
  end

  desc 'Move a series name from product names into a series (dry run unless the third argument is "run")'
  task :apply, [:brand_slug, :series_name, :mode] => :environment do |_task, args|
    brand = Brand.friendly.find(args.fetch(:brand_slug))
    series_name = args.fetch(:series_name).to_s.squish
    run = args[:mode] == 'run'
    prefix = /\A#{Regexp.escape(series_name)}\s+/i

    products = brand.products.select { |product| product.name.match?(prefix) }
    if products.empty?
      puts "No product of #{brand.display_name} starts with \"#{series_name}\"."
      next
    end

    puts run ? 'Changing:' : 'Dry run. Add ",run" to change the data:'
    ActiveRecord::Base.transaction do
      series = run ? brand.product_series.find_or_create_by!(name: series_name) : nil

      products.each do |product|
        new_name = product.name.sub(prefix, '')
        puts "  #{product.name} -> #{new_name} (series #{series_name})"
        next unless run

        product.name = new_name
        product.product_series = series
        product.save!
      end
    end
  end

  desc 'List products with the same brand, name and model no. in the same series (read-only)'
  task duplicates: :environment do
    rows = Product.group(:brand_id, :product_series_id, Arel.sql('LOWER(name)'), :model_no)
                  .having('COUNT(*) > 1')
                  .pluck(:brand_id, :product_series_id, Arel.sql('LOWER(name)'), :model_no, Arel.sql('COUNT(*)'))
    if rows.empty?
      puts 'No duplicates.'
      next
    end

    brands = Brand.where(id: rows.map(&:first)).index_by(&:id)
    rows.each do |brand_id, series_id, name, model_no, count|
      puts "#{brands[brand_id]&.display_name} | series #{series_id || '-'} | #{name} | #{model_no || '-'} | #{count}x"
    end
  end

  desc 'Make the slugs of all products in a series again (after a data migration)'
  task resync_slugs: :environment do
    Product.resync_slugs(Product.where.not(product_series_id: nil))
    puts 'Done.'
  end
end
