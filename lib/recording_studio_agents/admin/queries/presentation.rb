# frozen_string_literal: true

module RecordingStudioAgents
  module Admin
    module Queries
      module Presentation
        def format_tokens(value)
          return BLANK if value.nil?

          delimited_number(value)
        end

        def format_tools(value)
          return BLANK if value.nil?

          delimited_number(value)
        end

        def compact_tokens(value)
          count = value.to_i
          return "0" if count.zero?
          return compact_millions(count) if count >= 1_000_000
          return compact_thousands(count) if count >= 1_000

          count.to_s
        end

        def delimited_number(value)
          ActiveSupport::NumberHelper.number_to_delimited(value.to_i)
        end

        def percentage_change_label(current:, previous:)
          return "0%" if current.to_i.zero? && previous.to_i.zero?
          return "+100%" if previous.to_i.zero? && current.to_i.positive?

          format("%+.0f%%", ((current - previous) / previous.to_f) * 100)
        end

        def screen_href(context, key, **params)
          return unless context.respond_to?(:admin_screen_path)

          path = context.admin_screen_path(key)
          query = params.compact
          return path if query.empty?

          "#{path}?#{query.to_query}"
        end

        def hungry_label(agent_key:, tokens:)
          "#{agent_key} · #{compact_tokens(tokens)} tokens"
        end

        def agent_name(key, version: nil)
          agent_definition(key, version: version)&.name.presence || key.to_s
        end

        def agent_definition(key, version: nil)
          catalog = RecordingStudioAgents.agents.all
          key = key.to_s
          if version
            match = catalog.find { |item| item.key == key && item.version == Integer(version) }
            return match if match
          end

          catalog.select { |item| item.key == key }.max_by(&:version)
        end

        def selected_agent_key(context)
          request_param(context, :agent_key).to_s.presence
        end

        def selected_version(context)
          raw = request_param(context, :version)
          return if raw.blank?

          Integer(raw)
        rescue ArgumentError, TypeError
          nil
        end

        def selected_agent(context)
          key = selected_agent_key(context)
          return if key.blank?

          agent_definition(key, version: selected_version(context))
        end

        def selected_skill_key(context)
          request_param(context, :skill_key).to_s.presence
        end

        def selected_tool_key(context)
          request_param(context, :tool_key).to_s.presence
        end

        def selected_skill(context)
          key = selected_skill_key(context)
          return if key.blank?

          catalog_item(RecordingStudioAgents.skills.all, key: key, version: selected_version(context))
        end

        def selected_tool(context)
          key = selected_tool_key(context)
          return if key.blank? || !defined?(::RecordingStudioAI)

          catalog_item(RecordingStudioAI.tools.all, key: key, version: selected_version(context))
        end

        def agent_show_title(context)
          selected_agent(context)&.name.presence || "Agent"
        end

        def agent_show_subtitle(context)
          show_subtitle(selected_agent(context), missing: "That agent is not on the list.",
                                                 fallback: "What this agent is allowed to use.")
        end

        def skill_show_title(context)
          selected_skill(context)&.name.presence || "Skill"
        end

        def skill_show_subtitle(context)
          show_subtitle(selected_skill(context), missing: "That skill is not on the list.",
                                                 fallback: "How this skill tells the agent to work.")
        end

        def tool_show_title(context)
          selected_tool(context)&.name.presence || "Tool"
        end

        def tool_show_subtitle(context)
          show_subtitle(selected_tool(context), missing: "That tool is not on the list.",
                                                fallback: "What this tool can do.")
        end

        def agent_detail_rows(agent, context = nil)
          return [] unless agent

          [
            ["Key", agent.key],
            ["Version", agent.version],
            ["Enabled", Enablement.enabled?(agent) ? "On" : "Off"],
            ["Profile", profile_label(agent)],
            ["Instructions", agent.instructions.to_s.strip],
            ["Skills", linked_skill_references(agent.skills, context)],
            ["Extra skills", linked_skill_references(agent.optional_skills, context)],
            ["Skill packs", labeled_references(agent.packs, RecordingStudioAgents.skill_packs.all)],
            ["Tools", linked_tool_references(agent.tools, context)],
            ["Knowledge", labeled_references(agent.knowledge, RecordingStudioAgents.knowledge.all)],
            ["Can pass to", labeled_references(agent.handoffs, RecordingStudioAgents.agents.all)]
          ].map { |label, value| DetailRow.new(label: label, value: value) }
        end

        def profile_label(agent)
          name = Profiles.label(agent.profile || RecordingStudioAgents.configuration.profile)
          return name if agent.profile

          "#{name}, from the host"
        end

        def skill_detail_rows(skill, context = nil)
          return [] unless skill

          [
            ["Key", skill.key],
            ["Version", skill.version],
            ["Instructions", skill.instructions.to_s.strip],
            ["Tools", linked_tool_references(skill.required_tools, context)],
            ["Use when", presence_or_none(skill.use_when)],
            ["Don't use when", presence_or_none(skill.do_not_use_when)]
          ].map { |label, value| DetailRow.new(label: label, value: value) }
        end

        def tool_detail_rows(tool)
          return [] unless tool

          [
            ["Key", tool.key],
            ["Version", tool.version],
            ["Use when", presence_or_none(tool.use_when)],
            ["Don't use when", presence_or_none(tool.do_not_use_when)],
            ["Returns", presence_or_none(tool.returns)],
            ["Cost", tool.cost.to_s],
            ["Wait", tool.latency.to_s],
            ["Effect", tool.read_only ? "Looks only" : "Can change things"],
            ["Needs a yes", tool.requires_confirmation ? "On" : "Off"],
            ["Inputs", tool_inputs_label(tool)]
          ].map { |label, value| DetailRow.new(label: label, value: value) }
        end
      end
    end
  end
end
