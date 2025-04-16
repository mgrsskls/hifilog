# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in the app/assets
# folder are already added.
Rails.application.config.assets.precompile += %w(
  add_entity_dialog.css
  application.css
  bookmarks.css
  changelog.css
  contributions.css
  dashboard.css
  entity.css
  entity_form.css
  history.css
  home.css
  note.css
  note_editor.css
  numbers.css
  product.css
  profile.css
  search_results.css
  statistics.css
  tabs.css
  users.css

  application.js
  delete_form.js
  entity_form.js
  gallery.js
  notes.js
  theme_toggle.js
)
