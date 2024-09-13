class StaticController < ApplicationController
  include FormatHelper

  def changelog
    @html = markdown_to_html Rails.root.join('CHANGELOG.md').read
    @page_title = 'Changelog'
    @no_index = true

    render 'static'
  end

  def about
    @html = markdown_to_html Rails.root.join('static/about.md').read
    @page_title = 'About'

    render 'static'
  end

  def imprint
    @html = markdown_to_html Rails.root.join('static/imprint.md').read
    @page_title = 'imprint'
    @no_index = true

    render 'static'
  end

  def privacy_policy
    @html = markdown_to_html Rails.root.join('static/privacy_policy.md').read
    @page_title = 'Privacy Policy'
    @no_index = true

    render 'static'
  end
end
