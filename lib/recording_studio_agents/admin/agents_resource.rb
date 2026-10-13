# frozen_string_literal: true

module RecordingStudioAgents
  module Admin
    class AgentsResource < RecordingStudioAdmin::Resource
      key "registered_agents"
      section "agents"
      icon :sparkles
      title { Copy.t("admin.resource.agents.title") }
      # Keep as a literal: Admin search / resolvers may read resource subtitle raw.
      subtitle "Turn an agent on or off."

      action :turn_off,
             text: ->(_row, _context) { Copy.t("admin.resource.agents.turn_off") },
             icon: "pause",
             method: :post,
             confirm: lambda { |row, _context|
               Copy.t("admin.resource.agents.confirm_turn_off", name: row.name)
             },
             url: ->(row, context) { Queries.agent_enablement_href(row, :turn_off, context) },
             visible_if: ->(row, _context) { Enablement.enabled?(row) }

      action :turn_on,
             text: ->(_row, _context) { Copy.t("admin.resource.agents.turn_on") },
             icon: "play",
             method: :post,
             confirm: lambda { |row, _context|
               Copy.t("admin.resource.agents.confirm_turn_on", name: row.name)
             },
             url: ->(row, context) { Queries.agent_enablement_href(row, :turn_on, context) },
             visible_if: ->(row, _context) { !Enablement.enabled?(row) }
    end
  end
end
