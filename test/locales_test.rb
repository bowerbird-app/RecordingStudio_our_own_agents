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

  test "en.yml ships flash keys only under recording_studio.agents" do
    tree = locale_tree(File.join(engine_locales_dir, "en.yml"), "en")
           .fetch("recording_studio")
           .fetch("agents")

    assert_equal %w[flashes], tree.keys.sort
    assert_equal %w[agent_off agent_on], tree.fetch("flashes").keys.map(&:to_s).sort
    assert_equal FLASH_KEYS.fetch("flashes.agent_on"), tree.fetch("flashes").fetch("agent_on")
    assert_equal FLASH_KEYS.fetch("flashes.agent_off"), tree.fetch("flashes").fetch("agent_off")
  end

  # Wave-wide: probe / test-only keys stay under test/dummy (not gemspec-packaged
  # config/locales). Boot override targets real flashes.agent_off instead.
  test "packaged config/locales never ship probe or test-only keys" do
    locale_files = Dir[File.join(engine_locales_dir, "**", "*.{yml,yaml}")]
    assert_predicate locale_files, :any?

    locale_files.each do |path|
      source = File.read(path)
      refute_match(/\bHOST\b/, source,
                   "#{path} must not ship HOST probe English; use test/dummy locales")
      refute_match(/\b(probe|test[_-]only|for_test)\b/i, source,
                   "#{path} must not ship probe/test-only keys")
    end

    gemspec = File.read(File.expand_path("../recording_studio_agents.gemspec", __dir__))
    refute_match(%r{test/dummy}, gemspec,
                 "gemspec must not package test/dummy locale probes")
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

  test "admin dsl sources never call copy or i18n" do
    admin_root = File.expand_path("../lib/recording_studio_agents/admin", __dir__)
    sources = Dir[File.join(admin_root, "**", "*.rb")]
    assert_predicate sources, :any?

    sources.each do |path|
      source = File.read(path)
      refute_includes source, "Copy.t", "#{path} must keep Admin DSL values as literals"
      refute_match(/\bI18n\.t\b/, source, "#{path} must keep Admin DSL values as literals")
    end
  end

  # Reverting any translated flash string to a controller literal must fail here
  # (and fail the dummy boot-order / host-override render tests).
  test "translated flash keys keep Copy.t call sites and never hardcode main English" do
    controller_path = File.expand_path(
      "../app/controllers/recording_studio_agents/admin/agents_controller.rb",
      __dir__
    )
    source = File.read(controller_path)
    assert_predicate FLASH_KEYS, :any?

    FLASH_KEYS.each_key do |key|
      assert_includes source, "Copy.t(\"#{key}\"",
                      "#{controller_path} must call Copy.t(#{key.inspect}); " \
                      "reverting that flash to a literal must fail this test"
    end

    FLASH_KEYS.each_value do |english|
      refute_includes source, english.inspect,
                      "#{controller_path} must not embed en.yml English #{english.inspect}"
      refute_includes source, english,
                      "#{controller_path} must not embed en.yml English #{english.inspect}"
    end

    refute_match(/#\{[^}]+\} is on\./, source,
                 "#{controller_path} must not interpolate main's on-flash literal")
    refute_match(/#\{[^}]+\} is off\./, source,
                 "#{controller_path} must not interpolate main's off-flash literal")
  end

  test "english flash keys resolve from en.yml without defaults" do
    with_engine_locales_loaded do
      I18n.with_locale(:en) do
        FLASH_KEYS.each do |key, english|
          full_key = "recording_studio.agents.#{key}"

          assert_equal english, I18n.t(full_key, raise: true),
                       "#{full_key} should resolve to #{english.inspect}"
          assert_equal english, RecordingStudioAgents::Copy.t(key)
        end
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
        missing = RecordingStudioAgents::Copy.t("flashes.missing_key_for_test")
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
