class StaticController < ApplicationController
  def changelog
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML.new)

    @changelog = markdown.render(File.read(Rails.root.join('CHANGELOG.md')))
    @page_title = 'Changelog'
    @no_index = true
  end

  def about
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML.new)

    @html = markdown.render(File.read(Rails.root.join('about.md')))
    @page_title = 'About'
  end

  def privacy_policy
    @page_title = 'Privacy Policy'
    @no_index = true
  end
end
