# frozen_string_literal: true

module RecordingStudioAgents
  class Runtime
    module Records
      private

      def step_attributes(run, status, action_type, candidate_id, tool_key: nil, tool_version: nil,
                          argument_digest: nil, observation_summary: nil, controller_outcome: nil,
                          ai_run_id: nil, progress_made: nil, repeatable: false, sequence: nil)
        {
          sequence: sequence || next_sequence(run),
          status: status,
          action_type: action_type,
          candidate_id: candidate_id,
          tool_key: tool_key,
          tool_version: tool_version,
          argument_digest: argument_digest,
          observation_summary: observation_summary,
          observation_digest: observation_summary && Digests.of(observation_summary),
          progress_made: progress_made,
          controller_outcome: controller_outcome,
          recording_studio_ai_run_id: ai_run_id,
          repeatable: repeatable
        }
      end

      def next_sequence(run)
        run.agent_steps.maximum(:sequence).to_i + 1
      end

      def decision_record(verdict, menu)
        return {} unless verdict.tool?

        candidate = menu.fetch(verdict.candidate_id)
        return {} unless candidate&.tool?

        { "tool" => candidate.tool_key.to_s }
      end

      def plan_record(data)
        {
          "objective" => data["current_objective"].to_s,
          "plan" => string_lines(data["plan"]),
          "criteria" => criteria_lines(data["success_criteria"])
        }
      end

      def action_record(menu)
        { "actions" => menu.actionable.map { |candidate| action_line(candidate) } }
      end

      def action_line(candidate)
        return "#{candidate.handoff_key} v#{candidate.handoff_version}. #{candidate.purpose}" if candidate.handoff?
        return candidate.purpose unless candidate.tool?

        "#{candidate.tool_key} v#{candidate.tool_version}. #{candidate.purpose}"
      end

      def string_lines(value)
        Array(value).filter_map do |item|
          text = item.to_s.strip
          text unless text.empty?
        end
      end

      def criteria_lines(value)
        Array(value).filter_map do |item|
          text = item.is_a?(Hash) ? (item["text"] || item[:text]) : item
          line = text.to_s.strip
          line unless line.empty?
        end
      end

      def observations_present?(state)
        Array(state.data["recent_observations"]).any?
      end

      def signal_lines(state, run)
        Signals.lines(state: state, steps: run.agent_steps.count, configuration: configuration,
                      started_at: run.started_at)
      end
    end
  end
end
