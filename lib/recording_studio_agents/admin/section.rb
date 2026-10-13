# frozen_string_literal: true

module RecordingStudioAgents
  module Admin
    class Section < RecordingStudioAdmin::Section
      key "agents"
      icon :sparkles
      title { Copy.t("admin.section.title", default: "Agents admin") }
      subtitle do
        Copy.t(
          "admin.section.subtitle",
          default: "Who ran, what they tried, and how heavy the model calls were."
        )
      end

      link :agents,
           text: ->(_context) { Copy.t("admin.links.agents", default: "Agents") },
           url: ->(context) { context.admin_screen_path("registered_agents") }
      link :runs,
           text: ->(_context) { Copy.t("admin.links.runs", default: "Runs") },
           url: ->(context) { context.admin_screen_path("agent_runs") }
      link :tasks,
           text: ->(_context) { Copy.t("admin.links.tasks", default: "Tasks") },
           url: ->(context) { context.admin_screen_path("agent_tasks") }
      link :usage,
           text: ->(_context) { Copy.t("admin.links.usage", default: "Usage by agent") },
           url: ->(context) { context.admin_screen_path("agent_usage") }
      link :evaluations,
           text: ->(_context) { Copy.t("admin.links.evaluations", default: "Evaluations") },
           url: ->(context) { context.admin_screen_path("agent_evaluations") }
      # Admin only enables screens linked from a section. Keep this off the
      # hub unless an agent is selected, so a name can open the details page.
      link :agent,
           text: ->(_context) { Copy.t("admin.links.agent", default: "Agent") },
           url: ->(context) { context.admin_screen_path("registered_agent") },
           visible_if: ->(context) { Queries.selected_agent_key(context).present? }
      link :skill,
           text: ->(_context) { Copy.t("admin.links.skill", default: "Skill") },
           url: ->(context) { context.admin_screen_path("registered_skill") },
           visible_if: ->(context) { Queries.selected_skill_key(context).present? }
      link :tool,
           text: ->(_context) { Copy.t("admin.links.tool", default: "Tool") },
           url: ->(context) { context.admin_screen_path("registered_tool") },
           visible_if: ->(context) { Queries.selected_tool_key(context).present? }

      widget "widgets.agents.failed_runs"
      widget "widgets.agents.attempts_this_period"
      widget "widgets.agents.tokens_this_period"
      widget "widgets.agents.hungry_agents"
    end
  end
end
