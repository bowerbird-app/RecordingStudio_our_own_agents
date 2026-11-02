# frozen_string_literal: true

# Swaps the live Gemini and TypeSafe adapters for DummyStudioProvider when no key is set.
module DummyStudioProviders
  module_function

  def install!
    configuration = RecordingStudioAI.configuration
    if configuration.gemini_api_key.present? || configuration.openai_api_key.present?
      restore_live_providers!(configuration)
    else
      RecordingStudioAI.register_provider(:gemini, DummyStudioProvider.new(configuration: configuration))
      RecordingStudioAI.register_provider(:typesafe, DummyStudioProvider.new(configuration: configuration))
    end
    DummyOfflineTools.install!
  end

  def restore_live_providers!(configuration)
    RecordingStudioAI.register_provider(
      :gemini,
      RecordingStudioAI::Providers::Gemini.new(configuration: configuration)
    )
    RecordingStudioAI.register_provider(
      :typesafe,
      RecordingStudioAI::Providers::TypeSafe.new(configuration: configuration)
    )
  end
end
