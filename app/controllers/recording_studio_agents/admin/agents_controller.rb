# frozen_string_literal: true

module RecordingStudioAgents
  module Admin
    class AgentsController < RecordingStudioAdmin::ApplicationController
      def turn_on
        change_enabled!(:turn_on, true)
      end

      def turn_off
        change_enabled!(:turn_off, false)
      end

      private

      def change_enabled!(action_key, enabled)
        agent = load_agent!
        perform_recording_studio_admin_action!("registered_agents", action_key, agent) do
          Enablement.set!(agent: agent, enabled: enabled)
        end

        redirect_to registered_agents_screen_path,
                    notice: enablement_notice(agent, enabled)
      rescue ConfigurationError
        head :not_found
      end

      def load_agent!
        RecordingStudioAgents.agents.fetch(params[:agent_key], version: params[:version])
      rescue ConfigurationError
        raise ActiveRecord::RecordNotFound
      end

      # This controller inherits Admin's screen_path. That helper recalls
      # agent_key from the turn on / turn off request, and Admin's screen route
      # has no agent_key, so generation raises. The engine proxy does not recall
      # the request. script_name is the path recording_studio_admin_for stored
      # on the :admin surface.
      def registered_agents_screen_path
        RecordingStudioAdmin::Engine.routes.url_helpers.screen_path(
          "registered_agents",
          script_name: RecordingStudioAdmin.configuration.surface_for(:admin).path
        )
      end

      def enablement_notice(agent, enabled)
        if enabled
          Copy.t("flashes.agent_on", name: agent.name)
        else
          Copy.t("flashes.agent_off", name: agent.name)
        end
      end
    end
  end
end
