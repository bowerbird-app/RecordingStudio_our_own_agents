# frozen_string_literal: true

require "yaml"

# Gem unit tests do not boot a host Rails app, so Engine locale paths are not
# on I18n.load_path. Load English from config/locales/en.yml into the backend
# without appending I18n.load_path (forbidden in test_helper).
module I18nHelpers
  module_function

  def load_engine_english!
    return if @engine_english_loaded

    path = File.expand_path("../../config/locales/en.yml", __dir__)
    tree = YAML.safe_load_file(path, aliases: true).fetch("en")
    I18n.backend.store_translations(:en, tree)
    @engine_english_loaded = true
  end
end

I18nHelpers.load_engine_english!
