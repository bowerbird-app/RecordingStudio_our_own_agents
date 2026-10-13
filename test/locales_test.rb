# frozen_string_literal: true

require "test_helper"
require "yaml"

class LocalesTest < ActiveSupport::TestCase
  ADMIN_KEYS = {
    "admin.section.title" => "Agents admin",
    "admin.section.subtitle" => "Who ran, what they tried, and how heavy the model calls were.",
    "admin.links.agents" => "Agents",
    "admin.links.runs" => "Runs",
    "admin.links.tasks" => "Tasks",
    "admin.links.usage" => "Usage by agent",
    "admin.links.evaluations" => "Evaluations",
    "admin.links.agent" => "Agent",
    "admin.links.skill" => "Skill",
    "admin.links.tool" => "Tool",
    "admin.screens.agents.title" => "Agents",
    "admin.screens.runs.title" => "Runs",
    "admin.screens.tasks.title" => "Tasks",
    "admin.screens.usage.title" => "Usage by agent",
    "admin.screens.evaluations.title" => "Evaluations",
    "admin.resource.agents.title" => "Agents",
    "admin.resource.agents.turn_off" => "Turn off",
    "admin.resource.agents.turn_on" => "Turn on",
    "admin.resource.agents.confirm_turn_off" => "Turn off %{name}?",
    "admin.resource.agents.confirm_turn_on" => "Turn on %{name}?",
    "admin.buttons.runs" => "Runs",
    "admin.buttons.calls" => "Calls",
    "admin.summary.agents" => "Agents",
    "admin.chart.attempts_title" => "Attempts",
    "admin.chart.attempts_series" => "Attempts",
    "admin.widgets.failed_runs.title" => "Failed runs",
    "admin.widgets.failed_runs.info" =>
      "The last attempts that did not finish. Open Runs if you need to retry from the host.",
    "admin.widgets.attempts_this_period.title" => "Attempts this period",
    "admin.widgets.attempts_this_period.info" =>
      "How many times an agent started in the last 4 weeks, versus the 4 weeks before that.",
    "admin.widgets.tokens_this_period.title" => "Tokens this period",
    "admin.widgets.tokens_this_period.info" =>
      "Model-call tokens for those attempts. Shows blank if AI history was cleaned.",
    "admin.widgets.hungry_agents.title" => "Hungry agents",
    "admin.widgets.hungry_agents.info" => "Who used the most model-call tokens in the last 4 weeks.",
    "admin.widgets.period_label" => "Last 4 weeks"
  }.freeze

  FLASH_KEYS = {
    "flashes.agent_on" => "%{name} is on.",
    "flashes.agent_off" => "%{name} is off."
  }.freeze

  test "engine ships only english locale files" do
    files = Dir[File.join(engine_locales_dir, "*")].map { |path| File.basename(path) }

    assert_equal ["en.yml"], files.sort
  end

  test "engine exposes config/locales for rails i18n load path" do
    locale_path = File.expand_path(File.join(engine_locales_dir, "en.yml"))
    engine_locale_files = RecordingStudioAgents::Engine.paths["config/locales"].existent
                                                       .map { |path| File.expand_path(path) }

    assert_includes engine_locale_files, locale_path
  end

  test "lib ruby sources never append i18n load path" do
    lib_root = File.expand_path("../lib", __dir__)
    sources = Dir[File.join(lib_root, "**", "*.rb")]
    assert_predicate sources, :any?

    sources.each do |path|
      source = File.read(path)

      refute_includes source, "i18n.load_path",
                      "#{path} must not append app.config.i18n.load_path"
      refute_includes source, "I18n.load_path",
                      "#{path} must not append I18n.load_path"
    end
  end

  test "english keys resolve without missing translations" do
    with_engine_locales_loaded do
      I18n.with_locale(:en) do
        ADMIN_KEYS.each do |key, english|
          full_key = "recording_studio.agents.#{key}"
          translation = I18n.t(full_key, default: nil)

          assert_equal english, translation, "#{full_key} should resolve to #{english.inspect}"
          assert_equal english, I18n.t(full_key, raise: true)
          assert_equal english, RecordingStudioAgents::Copy.t(key, default: english)
        end

        FLASH_KEYS.each do |key, english|
          full_key = "recording_studio.agents.#{key}"
          translation = I18n.t(full_key, default: nil)

          assert_equal english, translation, "#{full_key} should resolve to #{english.inspect}"
          assert_equal english, I18n.t(full_key, raise: true)
        end
      end
    end
  end

  test "en.yml nests keys under recording_studio.agents" do
    tree = locale_tree(File.join(engine_locales_dir, "en.yml"), "en")
           .fetch("recording_studio")
           .fetch("agents")

    assert_equal FLASH_KEYS.fetch("flashes.agent_on"), tree.fetch("flashes").fetch("agent_on")
    assert_equal ADMIN_KEYS.fetch("admin.section.title"), tree.fetch("admin").fetch("section").fetch("title")
  end

  test "copy helper passes english default" do
    with_engine_locales_loaded do
      I18n.with_locale(:en) do
        assert_equal "Agents admin",
                     RecordingStudioAgents::Copy.t("admin.section.title", default: "Agents admin")
      end
    end
  end

  test "flash copy interpolates the agent name" do
    with_engine_locales_loaded do
      I18n.with_locale(:en) do
        assert_equal "Page librarian is on.",
                     RecordingStudioAgents::Copy.t(
                       "flashes.agent_on",
                       name: "Page librarian",
                       default: "%{name} is on."
                     )
        assert_equal "Page librarian is off.",
                     RecordingStudioAgents::Copy.t(
                       "flashes.agent_off",
                       name: "Page librarian",
                       default: "%{name} is off."
                     )
      end
    end
  end

  private

  def engine_locales_dir
    File.expand_path("../config/locales", __dir__)
  end

  def locale_tree(path, locale)
    YAML.safe_load_file(path, aliases: true).fetch(locale)
  end

  def with_engine_locales_loaded
    locale_path = File.expand_path(File.join(engine_locales_dir, "en.yml"))
    original_load_path = I18n.load_path.dup
    original_backend = I18n.backend

    I18n.load_path |= [locale_path]
    I18n.reload!
    yield
  ensure
    I18n.backend = original_backend
    I18n.load_path.replace(original_load_path)
    I18n.reload!
  end
end
