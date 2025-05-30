# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in the app/assets
# folder are already added.
Rails.application.config.assets.precompile += %w(
  active_admin.css
  add_entity_dialog.css
  amp_to_headphone_calculator.css
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
  statistics.css
  tabs.css
  users.css

  alpine.js
  amp_to_headphone_calculator.js
  application.js
  delete_form.js
  entity_form.js
  gallery.js
  notes.js
  signed_in.js
  theme_toggle.js
)
