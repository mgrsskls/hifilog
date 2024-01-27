class StaticController < ApplicationController
  def changelog
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML.new)

    @changelog = markdown.render(File.read(Rails.root.join('CHANGELOG.md')))
    @page_title = 'Changelog'
  end

  def about
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML.new)

    @html = markdown.render(File.read(Rails.root.join('README.md')))
    @page_title = 'About'
  end

  def privacy_policy
    @page_title = 'Privacy Policy'
  end
end
