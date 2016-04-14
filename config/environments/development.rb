Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true

  # Care if the mailer can't send.
  # Enable email previews
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.delivery_method = :test
  host = 'localhost:3000'
  config.action_mailer.default_url_options = { host: host }

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # serve from CDN
  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  #config.action_controller.asset_host = ENV['CLOUDFRONT_ENDPOINT']

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = false

  # Asset digests allow you to set far-future HTTP expiration dates on all assets,
  # yet still be able to expire them through the digest params.
  config.assets.digest = true

  # Adds additional error checking when serving assets at runtime.
  # Checks for improperly declared sprockets dependencies.
  # Raises helpful error messages.
  config.assets.raise_runtime_errors = true

  config.paperclip_defaults = {
    storage: :s3,
    # url: ':s3_alias_url',
    # s3_host_alias: ENV['CLOUDFRONT_ENDPOINT'],
    # path: '/:class/:attachment/:id_partition/:style/:filename',
    s3_protocol: 'http',
    s3_credentials: {
      bucket: ENV['S3_AVATAR_BUCKET'],
      access_key_id: ENV['AWS_ACCESS_KEY_ID'],
      secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
    },
  }

  #config.cache_store = :redis_store, "redis://localhost:6379/0/cache", {expires_in: 1.day}
  config.action_controller.perform_caching = false
end
