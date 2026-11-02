# frozen_string_literal: true

require "test_helper"

class ConcernSplitTest < Minitest::Test
  def test_runtime_keeps_call_public_and_steps_private
    runtime = RecordingStudioAgents::Runtime

    assert_includes runtime.public_instance_methods, :call
    assert_includes runtime.ancestors, runtime::Planning
    assert_includes runtime.ancestors, runtime::Decisions
    assert_includes runtime.ancestors, runtime::Performance
    assert_includes runtime.ancestors, runtime::Records
    %i[replan decide perform step_attributes].each do |name|
      refute_includes runtime.public_instance_methods, name
      assert_includes runtime.private_instance_methods, name
    end
  end

  def test_nothing_includes_or_extends_admin_queries
    queries = RecordingStudioAgents::Admin::Queries
    real_class = Object.instance_method(:class)
    offenders = ObjectSpace.each_object(Module).filter_map do |mod|
      next if real_class.bind_call(mod) == ActiveSupport::Deprecation::DeprecatedConstantProxy
      next if mod.equal?(queries)

      included = mod.ancestors.include?(queries)
      extended = mod.singleton_class.ancestors.include?(queries)
      next unless included || extended

      mod.name || mod.inspect
    end

    assert_empty offenders
  end

  def test_rubocop_names_the_split_files_that_miss_metrics
    rubocop = File.read(File.expand_path("../.rubocop.yml", __dir__))

    refute_includes rubocop, "runtime/**/*"
    refute_includes rubocop, "persistence/**/*"
    assert_includes rubocop, "lib/recording_studio_agents/runtime/performance.rb"
    assert_includes rubocop, "lib/recording_studio_agents/persistence/run_ledger.rb"
    refute_includes rubocop, "persistence/opening.rb"
  end

  def test_admin_queries_keep_the_same_module_api
    queries = RecordingStudioAgents::Admin::Queries

    assert_equal 5, queries::HUNGRY_LIMIT
    assert_respond_to queries, :agents
    assert_respond_to queries, :format_tokens
    assert_respond_to queries, :agent_name_cell
    assert_respond_to queries, :hungry_agents
    refute_respond_to queries, :profile_label
    assert queries.respond_to?(:profile_label, true)
    refute_respond_to queries, :trimmed_units
  end

  def test_persistence_classes_stay_addressable
    assert_equal :acquired, RecordingStudioAgents::Persistence::Opening.new(kind: :acquired, task: nil, run: nil).kind
    assert RecordingStudioAgents::Persistence::RunLedger::ACTIVITY_KEYS.key?("run_created")
  end
end
