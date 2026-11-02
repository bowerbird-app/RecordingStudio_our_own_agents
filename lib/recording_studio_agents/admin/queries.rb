# frozen_string_literal: true

require_relative "queries/scopes"
require_relative "queries/presentation"
require_relative "queries/cells"

module RecordingStudioAgents
  module Admin
    module Queries
      HUNGRY_LIMIT = 5
      BLANK = "-"
      WAITING_STATUSES = %w[pending running awaiting_confirmation].freeze
      STATUS_BADGES = {
        "pending" => { text: "Waiting", style: :default },
        "running" => { text: "Running", style: :info },
        "awaiting_confirmation" => { text: "Needs confirmation", style: :warning },
        "succeeded" => { text: "Succeeded", style: :success },
        "handoff_requested" => { text: "Passed on", style: :info },
        "failed" => { text: "Failed", style: :danger },
        "cancelled" => { text: "Cancelled", style: :default }
      }.freeze
      AI_JOIN = <<~SQL.squish
        INNER JOIN recording_studio_ai_runs
          ON recording_studio_ai_runs.id = recording_studio_agents_agent_runs.recording_studio_ai_run_id
      SQL

      ByAgentRow = Data.define(
        :agent_key,
        :agent_version,
        :attempts,
        :succeeded,
        :failed,
        :waiting,
        :avg_tokens,
        :avg_latency_ms,
        :avg_tools,
        :ai_sample_count
      )
      DetailRow = Data.define(:label, :value)
      NONE = "None"

      extend Scopes
      extend Presentation
      extend Cells

      class << self
        private :profile_label, :labeled_references, :linked_skill_references, :linked_tool_references,
                :linked_references, :linked_reference, :labeled_reference, :admin_link, :show_subtitle,
                :presence_or_none, :tool_inputs_label, :catalog_item, :request_param, :build_by_agent_row,
                :count_status, :average, :date_range_from_params, :filter_actor_context, :current_filter_actor,
                :enablement_route_proxy, :compact_thousands, :compact_millions, :trimmed_units
      end
    end
  end
end
