# frozen_string_literal: true

require "test_helper"
require "yaml"

class LocalesTest < ActiveSupport::TestCase
  # Expected English values come from en.yml (no hardcoded %{...} tokens in Ruby).
  ENGINE_ENGLISH = begin
    tree = YAML.safe_load_file(
      File.expand_path("../config/locales/en.yml", __dir__),
      aliases: true
    ).fetch("en").fetch("recording_studio").fetch("agents")

    flatten = lambda do |node, prefix = ""|
      node.each_with_object({}) do |(key, value), memo|
        path = prefix.empty? ? key.to_s : "#{prefix}.#{key}"
        if value.is_a?(Hash)
          memo.merge!(flatten.call(value, path))
        else
          memo[path] = value
        end
      end
    end

    flatten.call(tree).freeze
  end

  ADMIN_KEYS = ENGINE_ENGLISH.select { |key, _| key.start_with?("admin.") }.freeze
  FLASH_KEYS = ENGINE_ENGLISH.select { |key, _| key.start_with?("flashes.") }.freeze

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

  test "copy and controller call sites never pass english default" do
    roots = [
      File.expand_path("../lib", __dir__),
      File.expand_path("../app", __dir__)
    ]
    sources = roots.flat_map { |root| Dir[File.join(root, "**", "*.rb")] }
    assert_predicate sources, :any?

    sources.each do |path|
      source = File.read(path)
      next unless source.include?("Copy.t") || source.match?(/\bI18n\.t\b/)

      source.lines.each_with_index do |line, index|
        next unless line.include?("Copy.t") || line.include?("I18n.t")

        refute_match(/\bdefault:\s*["']/, line,
                     "#{path}:#{index + 1} must not pass English default: to Copy.t/I18n.t")
      end
    end
  end

  test "english keys resolve from en.yml without defaults" do
    with_engine_locales_loaded do
      I18n.with_locale(:en) do
        ADMIN_KEYS.each do |key, english|
          full_key = "recording_studio.agents.#{key}"

          assert_equal english, I18n.t(full_key, raise: true),
                       "#{full_key} should resolve to #{english.inspect}"
          assert_equal english, RecordingStudioAgents::Copy.t(key)
        end

        FLASH_KEYS.each do |key, english|
          full_key = "recording_studio.agents.#{key}"

          assert_equal english, I18n.t(full_key, raise: true),
                       "#{full_key} should resolve to #{english.inspect}"
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

  test "copy helper resolves english from en.yml" do
    with_engine_locales_loaded do
      I18n.with_locale(:en) do
        assert_equal "Agents admin", RecordingStudioAgents::Copy.t("admin.section.title")
      end
    end
  end

  test "flash copy interpolates the agent name" do
    with_engine_locales_loaded do
      I18n.with_locale(:en) do
        assert_equal "Page librarian is on.",
                     RecordingStudioAgents::Copy.t("flashes.agent_on", name: "Page librarian")
        assert_equal "Page librarian is off.",
                     RecordingStudioAgents::Copy.t("flashes.agent_off", name: "Page librarian")
      end
    end
  end

  test "missing keys follow normal i18n missing behavior" do
    with_engine_locales_loaded do
      I18n.with_locale(:en) do
        missing = RecordingStudioAgents::Copy.t("admin.section.missing_key_for_test")
        assert_match(/translation missing/i, missing.to_s)
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
    I18nHelpers.load_engine_english!
  end
end
