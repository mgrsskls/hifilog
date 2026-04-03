# frozen_string_literal: true

class SitemapController < ApplicationController
  def show
    respond_to do |format|
      format.xml do
        brand_updated_at = Brand.maximum(:updated_at)
        product_updated_at = Product.maximum(:updated_at)
        product_variant_updated_at = ProductVariant.maximum(:updated_at)

        @pages = build_sitemap_xml_pages(brand_updated_at, product_updated_at, product_variant_updated_at)
        @sitemap_root_lastmod = [brand_updated_at, product_updated_at, product_variant_updated_at].compact.max
      end
      format.html do
        @brands = Brand.order(:name)
      end
    end
  end

  private

  def build_sitemap_xml_pages(brand_updated_at, product_updated_at, product_variant_updated_at)
    pages = []

    pages << {
      url: users_url,
      updated: User.maximum(:updated_at)
    }
    User.where(profile_visibility: 2).find_each do |user|
      pages << {
        url: user_url(user.user_name.downcase),
        updated: user.updated_at
      }
    end

    pages << {
      url: events_url,
      updated: Event.maximum(:updated_at)
    }
    pages << {
      url: about_url
    }
    pages << {
      url: calculators_root_url
    }
    pages << {
      url: calculators_resistors_for_amplifier_to_headphone_adapter_url
    }

    pages << {
      url: brands_url,
      updated: brand_updated_at
    }
    Brand.select(:id, :slug, :updated_at).find_each do |brand|
      pages << {
        url: brand_url(brand),
        updated: brand.updated_at
      }
    end

    pages << {
      url: products_url,
      updated: [product_updated_at, product_variant_updated_at].compact.max
    }
    Product.select(:id, :slug, :updated_at).find_each do |product|
      pages << {
        url: product_url(
          id: product.friendly_id
        ),
        updated: product.updated_at
      }
    end
    ProductVariant.select(:id, :slug, :product_id, :updated_at).includes(:product).find_each do |product_variant|
      pages << {
        url: product_variant_url(
          id: product_variant.friendly_id,
          product_id: product_variant.product.friendly_id
        ),
        updated: product_variant.updated_at
      }
    end

    pages.uniq
  end
end
