# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in the app/assets
# folder are already added.
Rails.application.config.assets.precompile += %w(
  accordion_tabs.css
  application.css
  changelog.css
  dashboard.css
  home.css
  new_product.css
  product.css
  search_results.css
  setups.css
  users.css
  user_form.css

  application.js
  accordion_tabs.js
  table_saw.js
  theme_toggle.js
)
