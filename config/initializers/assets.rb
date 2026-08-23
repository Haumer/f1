# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path

# World country outlines for the circuit calendar map. Kept out of
# app/assets/images since it's data, not an image, and it's fetched at runtime
# by the circuit-map Stimulus controller rather than bundled into application.js.
Rails.application.config.assets.paths << Rails.root.join("app/assets/geo")

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in the app/assets
# folder are already added.
# Rails.application.config.assets.precompile += %w( admin.js admin.css )
Rails.application.config.assets.precompile += %w(bootstrap.min.js popper.js)
