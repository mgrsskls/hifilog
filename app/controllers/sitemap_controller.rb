# frozen_string_literal: true

class SitemapController < ApplicationController
  def show
    respond_to do |format|
      format.xml do
        builder = SitemapBuilder.new(url_options:)
        @pages = builder.pages
        @sitemap_root_lastmod = builder.root_lastmod
      end
    end
  end
end
