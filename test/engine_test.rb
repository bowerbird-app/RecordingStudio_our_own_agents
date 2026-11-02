# frozen_string_literal: true

require "test_helper"

class EngineTest < Minitest::Test
  def setup
    @original_configuration = RecordingStudioAgents.configuration
    RecordingStudioAgents.configuration = RecordingStudioAgents::Configuration.new
  end

  def teardown
    RecordingStudioAgents.configuration.hooks.clear!
    RecordingStudioAgents.configuration = @original_configuration
  end

  def test_before_and_after_initialize_initializers_run_hooks
    before_called = false
    after_called = false

    RecordingStudioAgents.configuration.hooks.before_initialize { |_engine| before_called = true }
    RecordingStudioAgents.configuration.hooks.after_initialize { |_engine| after_called = true }

    find_initializer("recording_studio_agents.before_initialize").block.call(Object.new)
    find_initializer("recording_studio_agents.after_initialize").block.call(Object.new)

    assert before_called
    assert after_called
  end

  def test_load_config_merges_config_sources_and_runs_on_configuration_hook
    hook_called = false
    hook_payload = nil
    RecordingStudioAgents.configuration.hooks.on_configuration do |cfg|
      hook_called = true
      hook_payload = cfg
    end

    xcfg = Struct.new(:recording_studio_agents).new({ lease_seconds: 45 })
    app_config = Struct.new(:x).new(xcfg)
    with_config_root do |paths|
      app = Struct.new(:config, :paths) do
        def config_for(_name)
          { lease_seconds: 12 }
        end
      end.new(app_config, paths)

      find_initializer("recording_studio_agents.load_config").block.call(app)
    end

    assert hook_called
    assert_equal RecordingStudioAgents.configuration, hook_payload
    assert_equal 45, RecordingStudioAgents.configuration.lease_seconds
  end

  def test_load_config_handles_errors_and_each_pair_fallback
    pair_config = Class.new do
      def each_pair
        yield(:lease_seconds, 15)
      end
    end.new

    xcfg = Struct.new(:recording_studio_agents).new(pair_config)
    app_config = Struct.new(:x).new(xcfg)

    with_config_root(write_yaml: false) do |paths|
      app = Struct.new(:config, :paths) do
        def config_for(_name)
          raise "config_for should not run when the yaml file is missing"
        end
      end.new(app_config, paths)

      find_initializer("recording_studio_agents.load_config").block.call(app)
    end

    assert_equal 15, RecordingStudioAgents.configuration.lease_seconds
  end

  def test_load_config_does_not_hide_each_pair_errors
    bad_pair_config = Class.new do
      def each_pair
        raise "bad pair"
      end
    end.new

    xcfg = Struct.new(:recording_studio_agents).new(bad_pair_config)
    app_config = Struct.new(:x).new(xcfg)
    error = with_config_root do |paths|
      app = Struct.new(:config, :paths) do
        def config_for(_name)
          { lease_seconds: 80 }
        end
      end.new(app_config, paths)

      assert_raises(RuntimeError) do
        find_initializer("recording_studio_agents.load_config").block.call(app)
      end
    end

    assert_equal "bad pair", error.message
  end

  def test_load_config_does_not_hide_no_method_error
    with_config_root do |paths|
      app = Struct.new(:config, :paths) do
        def config_for(_name)
          raise NoMethodError, "config boom"
        end
      end.new(Object.new, paths)

      assert_raises(NoMethodError) do
        find_initializer("recording_studio_agents.load_config").block.call(app)
      end
    end
  end

  def test_load_config_raises_yaml_syntax_errors
    with_config_root do |paths|
      File.write(File.join(paths["config"].existent.first, "recording_studio_agents.yml"), "lease_seconds: [\n")
      app = Struct.new(:config, :paths) do
        def config_for(name)
          yaml = Pathname.new(paths["config"].existent.first).join("#{name}.yml")
          ActiveSupport::ConfigurationFile.parse(yaml)
        end
      end.new(Object.new, paths)

      error = assert_raises(RuntimeError) do
        find_initializer("recording_studio_agents.load_config").block.call(app)
      end

      assert_includes error.message, "YAML syntax error"
    end
  end

  def test_load_config_is_noop_without_config_sources
    app = Struct.new(:config).new(Object.new)

    find_initializer("recording_studio_agents.load_config").block.call(app)

    assert_equal 300, RecordingStudioAgents.configuration.lease_seconds
  end

  def test_load_config_ignores_non_enumerable_yaml
    yaml = Object.new

    xcfg = Struct.new(:recording_studio_agents).new({ lease_seconds: 22 })
    app_config = Struct.new(:x).new(xcfg)
    with_config_root do |paths|
      app = Struct.new(:config, :paths) do
        attr_accessor :yaml

        def config_for(_name)
          @yaml
        end
      end.new(app_config, paths)
      app.yaml = yaml

      find_initializer("recording_studio_agents.load_config").block.call(app)
    end

    assert_equal 22, RecordingStudioAgents.configuration.lease_seconds
  end

  def test_after_initialize_warns_when_extension_hooks_are_registered
    RecordingStudioAgents.configuration.hooks.extend_model(:page) { nil }
    RecordingStudioAgents.configuration.hooks.extend_controller("pages") { nil }

    messages = []
    logger = Object.new
    logger.define_singleton_method(:warn) { |message| messages << message }

    Rails.stub(:logger, logger) do
      RecordingStudioAgents::Engine.warn_unused_extension_hooks!
    end

    assert_equal 1, messages.length
    assert_includes messages.first, "apply_model_extensions"
    assert_includes messages.first, "extend_model blocks for page"
    assert_includes messages.first, "extend_controller blocks for pages"
  end

  def test_after_initialize_stays_quiet_without_extension_hooks
    messages = []
    logger = Object.new
    logger.define_singleton_method(:warn) { |message| messages << message }

    Rails.stub(:logger, logger) do
      RecordingStudioAgents::Engine.warn_unused_extension_hooks!
    end

    assert_empty messages
  end

  def test_engine_does_not_class_eval_host_models_or_controllers
    source = File.read(File.expand_path("../lib/recording_studio_agents/engine.rb", __dir__))
    names = RecordingStudioAgents::Engine.initializers.map(&:name)

    refute_includes source, "class_eval"
    refute_includes source, "def apply_model_extensions"
    refute_includes source, "def apply_controller_extensions"
    assert_includes source, "warn_unused_extension_hooks!"
    refute_includes names, "recording_studio_agents.apply_model_extensions"
    refute_includes names, "recording_studio_agents.apply_controller_extensions"
    assert_includes names, "recording_studio_agents.before_initialize"
    assert_includes names, "recording_studio_agents.load_config"
  end

  private

  def find_initializer(name)
    RecordingStudioAgents::Engine.initializers.find { |initializer| initializer.name == name }
  end

  def with_config_root(write_yaml: true)
    dir = Dir.mktmpdir
    File.write(File.join(dir, "recording_studio_agents.yml"), "shared: {}\n") if write_yaml
    yield({ "config" => Struct.new(:existent).new([dir]) })
  ensure
    FileUtils.rm_rf(dir) if dir
  end
end
