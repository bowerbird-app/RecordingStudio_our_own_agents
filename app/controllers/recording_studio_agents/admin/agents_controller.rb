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
      rescue RecordingStudioAdmin::AuthorizationFailed, RecordingStudioAdmin::DefinitionNotFound
        head :forbidden
      rescue ConfigurationError
        head :not_found
      end

      def load_agent!
        RecordingStudioAgents.agents.fetch(params[:agent_key], version: params[:version])
      rescue ConfigurationError
        raise ActiveRecord::RecordNotFound
      end

      def registered_agents_screen_path
        mount = RecordingStudioAdmin.configuration.default_mount_path.to_s.sub(%r{/*\z}, "")
        "#{mount}/screens/registered_agents"
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
