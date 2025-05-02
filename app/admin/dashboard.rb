# frozen_string_literal: true
ActiveAdmin.register_page "Dashboard" do
  menu false

  content title: proc { I18n.t("active_admin.dashboard") } do
    div class: "flex flex-col gap-8 mb-16" do
      all_brands_count = Brand.all.count
      all_products_count = Product.all.count
      div do
        discontinued_brands_count = Brand.where(discontinued: true).count
        brands_with_products_count = Brand.joins(:products).distinct.count
        brands_with_sub_categories_count = Brand.left_outer_joins(:sub_categories).where.not(sub_categories: { id: nil }).distinct.count
        brands_with_country_count = Brand.where.not(country_code: nil).count
        brands_with_website_count = Brand.where.not(website: nil).count
        brands_with_description_count = Brand.where.not(description: nil).count
        brands_with_founded_year_count = Brand.where.not(founded_year: nil).count
        h3 class: "text-xl font-bold mb-2" do
          "#{all_brands_count} Brands"
        end
        dl class: "grid grid-cols-[repeat(auto-fill,_minmax(10rem,_1fr))] gap-4" do
          div do
            dt class: "font-bold text-gray-700" do
              "With Categories"
            end
            dd "#{number_to_rounded(brands_with_sub_categories_count / all_brands_count.to_f * 100, precision: 2)}%" do
              small "(#{brands_with_sub_categories_count})"
            end
          end
          div do
            dt class: "font-bold text-gray-700" do
              "With Products"
            end
            dd "#{number_to_rounded(brands_with_products_count / all_brands_count.to_f * 100, precision: 2)}%" do
              small "(#{brands_with_products_count})"
            end
          end
          div do
            dt class: "font-bold text-gray-700" do
              "Products per Brand"
            end
            dd number_to_rounded(all_products_count / all_brands_count .to_f, precision: 2)
          end
        end
        dl class: "grid grid-cols-[repeat(auto-fill,_minmax(10rem,_1fr))] gap-4 mt-4" do
          div do
            dt class: "font-bold text-gray-700" do
              "Discontinued"
            end
            dd "#{number_to_rounded(discontinued_brands_count / all_brands_count.to_f * 100, precision: 2)}%" do
              small "(#{discontinued_brands_count})"
            end
          end
          div do
            dt class: "font-bold text-gray-700" do
              "Description"
            end
            dd "#{number_to_rounded(brands_with_description_count / all_brands_count.to_f * 100, precision: 2)}%" do
              small "(#{brands_with_description_count})"
            end
          end
          div do
            dt class: "font-bold text-gray-700" do
              "Founded Year"
            end
            dd "#{number_to_rounded(brands_with_founded_year_count / all_brands_count.to_f * 100, precision: 2)}%" do
              small "(#{brands_with_founded_year_count})"
            end
          end
          div do
            dt class: "font-bold text-gray-700" do
              "Country"
            end
            dd "#{number_to_rounded(brands_with_country_count / all_brands_count.to_f * 100, precision: 2)}%" do
              small "(#{brands_with_country_count})"
            end
          end
          div do
            dt class: "font-bold text-gray-700" do
              "Website"
            end
            dd "#{number_to_rounded(brands_with_website_count / all_brands_count.to_f * 100, precision: 2)}%" do
              small "(#{brands_with_website_count})"
            end
          end
        end
      end
      div do
        discontinued_products_count = Product.where(discontinued: true).count
        products_with_variants_count = Product.joins(:product_variants).distinct.count
        diy_kit_products_count = Product.where(diy_kit: true).count
        products_with_release_year_count = Product.where.not(release_year: nil).count
        products_with_description_count = Product.where.not(description: nil).count
        products_with_price_count = Product.where.not(price: nil).count
        h3 class: "text-xl font-bold mb-2" do
          "#{all_products_count} Products"
        end
        dl class: "grid grid-cols-[repeat(auto-fill,_minmax(10rem,_1fr))] gap-4" do
          div do
            dt class: "font-bold text-gray-700" do
              "Discontinued"
            end
            dd "#{number_to_rounded(discontinued_products_count / all_products_count.to_f * 100, precision: 2)}%" do
              small "(#{discontinued_products_count})"
            end
          end
          div do
            dt class: "font-bold text-gray-700" do
              "Description"
            end
            dd "#{number_to_rounded(products_with_description_count / all_products_count.to_f * 100, precision: 2)}%" do
              small "(#{products_with_description_count})"
            end
          end
          div do
            dt class: "font-bold text-gray-700" do
              "Released Year"
            end
            dd "#{number_to_rounded(products_with_release_year_count / all_products_count.to_f * 100, precision: 2)}%" do
              small "(#{products_with_release_year_count})"
            end
          end
          div do
            dt class: "font-bold text-gray-700" do
              "DIY Kit"
            end
            dd "#{number_to_rounded(diy_kit_products_count / all_products_count.to_f * 100, precision: 2)}%" do
              small "(#{diy_kit_products_count})"
            end
          end
          div do
            dt class: "font-bold text-gray-700" do
              "Price"
            end
            dd "#{number_to_rounded(products_with_price_count / all_products_count.to_f * 100, precision: 2)}%" do
              small "(#{products_with_price_count})"
            end
          end
          div do
            dt class: "font-bold text-gray-700" do
              "With Variants"
            end
            dd "#{number_to_rounded(products_with_variants_count / all_products_count.to_f * 100, precision: 2)}%" do
              small "(#{products_with_variants_count})"
            end
          end
        end
      end
      div do
        all_product_variants_count = ProductVariant.all.count
        discontinued_product_variants_count = ProductVariant.where(discontinued: true).count
        diy_kit_product_variants_count = ProductVariant.where(diy_kit: true).count
        product_variants_with_release_year_count = ProductVariant.where.not(release_year: nil).count
        product_variants_with_description_count = ProductVariant.where.not(description: nil).count
        product_variants_with_price_count = ProductVariant.where.not(price: nil).count
        h3 class: "text-xl font-bold mb-2" do
          "#{all_product_variants_count} Product Variants"
        end
        dl class: "grid grid-cols-[repeat(auto-fill,_minmax(10rem,_1fr))] gap-4" do
          div do
            dt class: "font-bold text-gray-700" do
              "Discontinued"
            end
            dd "#{number_to_rounded(discontinued_product_variants_count / all_product_variants_count.to_f * 100, precision: 2)}%" do
              small "(#{discontinued_product_variants_count})"
            end
          end
          div do
            dt class: "font-bold text-gray-700" do
              "Description"
            end
            dd "#{number_to_rounded(product_variants_with_description_count / all_product_variants_count.to_f * 100, precision: 2)}%" do
              small "(#{product_variants_with_description_count})"
            end
          end
          div do
            dt class: "font-bold text-gray-700" do
              "Released Year"
            end
            dd "#{number_to_rounded(product_variants_with_release_year_count / all_product_variants_count.to_f * 100, precision: 2)}%" do
              small "(#{product_variants_with_release_year_count})"
            end
          end
          div do
            dt class: "font-bold text-gray-700" do
              "DIY Kit"
            end
            dd "#{number_to_rounded(diy_kit_product_variants_count / all_product_variants_count.to_f * 100, precision: 2)}%" do
              small "(#{diy_kit_product_variants_count})"
            end
          end
          div do
            dt class: "font-bold text-gray-700" do
              "Price"
            end
            dd "#{number_to_rounded(product_variants_with_price_count / all_product_variants_count.to_f * 100, precision: 2)}%" do
              small "(#{product_variants_with_price_count})"
            end
          end
        end
      end
    end

    section do
      h3 class: "text-xl font-bold mb-4" do
        "Recent Activity"
      end
      table_for PaperTrail::Version.where.not(event: :destroy).order('id desc').limit(50) do
        column :id
        column :item_type
        column ("Item") do |v|
          if v.item_type == "Product"
            Product.where(id: v.item_id).last || "deleted"
          elsif v.item_type == "Brand"
            Brand.where(id: v.item_id).last || "deleted"
          end
        end
        column :event
        column ("User") do |v|
          v.whodunnit ? User.find(v.whodunnit) : "-"
        end
        column :created_at
      end
    end
  end
end
