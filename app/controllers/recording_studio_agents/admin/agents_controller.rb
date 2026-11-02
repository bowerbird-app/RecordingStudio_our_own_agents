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

      # screen_path on this engine controller is Admin's route helper. It recalls
      # agent_key from the turn on / turn off route, and that route has no
      # agent_key, so generation raises. Hide the helper for this call so
      # admin_screen_path uses Admin's mount path.
      def registered_agents_screen_path
        singleton_class.undef_method(:screen_path)
        recording_studio_admin_context.admin_screen_path("registered_agents")
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
