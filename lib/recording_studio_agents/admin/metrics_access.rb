# frozen_string_literal: true

module RecordingStudioAgents
  module Admin
    # Staff view check for site metrics. Metrics registers the proc; this helper
    # calls Accessible. It does not invent an admin flag.
    module MetricsAccess
      module_function

      ResolverContext = Struct.new(:controller)

      def authorize
        @authorize ||= ->(context) { can_view?(context) }
      end

      def can_view?(context)
        authorized_on_admin_root?(context, :view)
      end

      def admin_root_recording
        resolver = RecordingStudioAdmin.configuration.access_recording_resolver
        return unless resolver

        resolver.call(ResolverContext.new(nil))
      end

      def actor_for(context)
        context&.access_grant&.actor
      end

      def authorized_on_admin_root?(context, role)
        actor = actor_for(context)
        recording = admin_root_recording
        return false if actor.blank? || recording.blank?

        RecordingStudioAccessible.authorized?(
          actor: actor,
          recording: recording,
          role: role
        )
      end
    end
  end
end
