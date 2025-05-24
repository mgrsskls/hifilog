class StaticController < ApplicationController
  include FormatHelper
  content_security_policy false, only: [:amp_to_headphone_calculator]

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

  def calculators
    @active_menu = :calculators
  end

  def amp_to_headphone_calculator
    @active_menu = :calculators
    @reduced_layout = true
    @meta_desc = 'Calculate resistors for an amplifier-to-headphone adapter using an L-Pad, ' \
                 'a reversed L-Pad or a three resistor network.'
    @page_title = 'Calculate Resistors for an Amplifier-to-Headphone Adapter'
    render 'amp_to_headphone_calculator'
  end
end
