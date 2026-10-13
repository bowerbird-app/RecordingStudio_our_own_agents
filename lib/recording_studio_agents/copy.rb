# frozen_string_literal: true

require "i18n"

module RecordingStudioAgents
  # Rails I18n lookups for Agents user-facing copy. Every call passes
  # `default:` English so a host locale without a fallback never shows
  # "translation missing".
  module Copy
    PREFIX = "recording_studio.agents"

    module_function

    def t(key, **)
      I18n.t("#{PREFIX}.#{key}", **)
    end
  end
end
