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
