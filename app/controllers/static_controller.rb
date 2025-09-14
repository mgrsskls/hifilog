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
    @meta_desc = 'HiFi Log is a user-driven database for hi-fi products and brands. ' \
                 'Read more about its founder and how to support hifilog.com.'

    render 'static'
  end

  def imprint
    @html = markdown_to_html Rails.root.join('static/imprint.md').read
    @page_title = 'Imprint'
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
    @page_title = 'Calculators'
    @active_menu = :calculators
    @meta_desc = 'HiFi Log provides some calculators that can be useful for your DIY hi-fi projects. ' \
                 'HiFi Log is a user-driven database for hi-fi products and brands.'
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
