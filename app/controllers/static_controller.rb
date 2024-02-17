class StaticController < ApplicationController
  def changelog
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML.new)

    @html = markdown.render(File.read(Rails.root.join('CHANGELOG.md')))
    @page_title = 'Changelog'
    @no_index = true

    render 'static'
  end

  def about
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML.new)

    @html = markdown.render(File.read(Rails.root.join('static/about.md')))
    @page_title = 'About'

    render 'static'
  end

  def imprint
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML.new)

    @html = markdown.render(File.read(Rails.root.join('static/imprint.md')))
    @page_title = 'imprint'
    @no_index = true

    render 'static'
  end

  def privacy_policy
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML.new)

    @html = markdown.render(File.read(Rails.root.join('static/privacy_policy.md')))
    @page_title = 'Privacy Policy'
    @no_index = true

    render 'static'
  end
end
