# frozen_string_literal: true

require "i18n"

module RecordingStudioAgents
  # Rails I18n lookups for Agents user-facing copy. English comes only from
  # `config/locales/en.yml`. Missing keys follow normal I18n behavior
  # (translation missing / raise-on-missing); there is no English `default:`.
  module Copy
    PREFIX = "recording_studio.agents"

    module_function

    def t(key, **)
      I18n.t("#{PREFIX}.#{key}", **)
    end
  end
end
