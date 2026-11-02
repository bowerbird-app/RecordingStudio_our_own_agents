# frozen_string_literal: true

module RecordingStudioAgents
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioAgents

    class << self
      def agents_config_yaml(app)
        return unless app.respond_to?(:paths)

        config_paths = app.paths["config"]
        return unless config_paths.respond_to?(:existent)

        root = Array(config_paths.existent).first
        return if root.blank?

        Pathname.new(root).join("recording_studio_agents.yml")
      end
    end

    initializer "recording_studio_agents.before_initialize", before: "recording_studio_agents.load_config" do |_app|
      RecordingStudioAgents.configuration.hooks.run(:before_initialize, self)
    end

    initializer "recording_studio_agents.load_config" do |app|
      if RecordingStudioAgents::Engine.agents_config_yaml(app)&.exist?
        yaml = app.config_for(:recording_studio_agents)
        RecordingStudioAgents.configuration.merge!(yaml) if yaml.respond_to?(:each)
      end

      if app.config.respond_to?(:x) && app.config.x.respond_to?(:recording_studio_agents)
        xcfg = app.config.x.recording_studio_agents
        if xcfg.respond_to?(:to_h)
          RecordingStudioAgents.configuration.merge!(xcfg.to_h)
        elsif xcfg.respond_to?(:each_pair)
          hash = {}
          xcfg.each_pair { |k, v| hash[k] = v }
          RecordingStudioAgents.configuration.merge!(hash) if hash.any?
        end
      end

      RecordingStudioAgents.configuration.hooks.run(:on_configuration, RecordingStudioAgents.configuration)
    end

    initializer "recording_studio_agents.after_initialize", after: "recording_studio_agents.load_config" do |_app|
      RecordingStudioAgents.configuration.hooks.run(:after_initialize, self)
    end

    initializer "recording_studio_agents.admin" do
      config.to_prepare do
        RecordingStudioAgents::Admin.register!
      end
    end

    initializer "recording_studio_agents.finalize" do
      config.after_initialize do
        RecordingStudioAgents.finalize!
      end
    end
  end
end
