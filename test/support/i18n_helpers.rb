# frozen_string_literal: true

# Gem unit tests do not boot a host Rails app, so Engine locale paths are not
# registered. Put config/locales/en.yml on I18n.load_path here (not in
# test_helper) so I18n.reload! keeps English available for Copy.t.
module I18nHelpers
  module_function

  def engine_locale_path
    File.expand_path("../../config/locales/en.yml", __dir__)
  end

  def load_engine_english!
    path = File.expand_path(engine_locale_path)
    expanded = I18n.load_path.map { |entry| File.expand_path(entry) }
    return if expanded.include?(path)

    I18n.load_path << path
    I18n.reload!
  end
end

I18nHelpers.load_engine_english!
