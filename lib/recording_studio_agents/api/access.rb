# frozen_string_literal: true

require "active_support/deprecation"

module RecordingStudioAgents
  module Api
    # Removed in the next release. Call RecordingStudioAgents::Admin::MetricsAccess.
    DEPRECATOR = ActiveSupport::Deprecation.new("0.9.0", "RecordingStudioAgents")

    Access = ActiveSupport::Deprecation::DeprecatedConstantProxy.new(
      "RecordingStudioAgents::Api::Access",
      "RecordingStudioAgents::Admin::MetricsAccess",
      DEPRECATOR
    )
  end
end
