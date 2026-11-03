# frozen_string_literal: true

RecordingStudioAccessible.configure do |config|
  config.layout = "recording_studio/default_layout"
  config.access_actor_types = [ "User" ]
end
