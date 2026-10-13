# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class AdminI18nRenderTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.find_or_create_by!(email: "admin-i18n-render@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    grant_accessible!(recording: RecordingStudio.root_recording_for(admin_root), actor: @user)
  end

  test "admin dsl chrome stays main english string literals" do
    assert_equal "Agents admin", RecordingStudioAgents::Admin::Section.title
    assert_equal "Who ran, what they tried, and how heavy the model calls were.",
                 RecordingStudioAgents::Admin::Section.subtitle
    assert_equal "Agents", RecordingStudioAgents::Admin::AgentsScreen.title
    assert_equal "Including agents that have not run yet.",
                 RecordingStudioAgents::Admin::AgentsScreen.subtitle
    assert_equal "Runs", RecordingStudioAgents::Admin::RunsScreen.title
    assert_equal "One attempt each. Steps lists the work in order.",
                 RecordingStudioAgents::Admin::RunsScreen.subtitle
    assert_equal "Goals given to an agent.",
                 RecordingStudioAgents::Admin::TasksScreen.subtitle
    assert_equal "Usage by agent", RecordingStudioAgents::Admin::UsageScreen.title
    assert_equal "Attempts, outcomes, and average tokens.",
                 RecordingStudioAgents::Admin::UsageScreen.subtitle
    assert_equal "Evaluations", RecordingStudioAgents::Admin::EvaluationsScreen.title
    assert_equal "Pass, fail, or still deciding.",
                 RecordingStudioAgents::Admin::EvaluationsScreen.subtitle
    assert_equal "Agents", RecordingStudioAgents::Admin::AgentsResource.title
    assert_equal "Turn an agent on or off.",
                 RecordingStudioAgents::Admin::AgentsResource.subtitle
    assert_equal "Turn off", RecordingStudioAgents::Admin::AgentsResource.action_for(:turn_off).text
    assert_equal "Turn on", RecordingStudioAgents::Admin::AgentsResource.action_for(:turn_on).text

    link_texts = RecordingStudioAgents::Admin::Section.links_value.filter_map do |link|
      link.text if link.visible_if.nil?
    end
    assert_equal ["Agents", "Runs", "Tasks", "Usage by agent", "Evaluations"], link_texts

    [
      RecordingStudioAgents::Admin::Section.title,
      RecordingStudioAgents::Admin::Section.subtitle,
      RecordingStudioAgents::Admin::AgentsScreen.title,
      RecordingStudioAgents::Admin::AgentsResource.action_for(:turn_off).text,
      link_texts.first
    ].each do |value|
      assert_kind_of String, value
      refute_respond_to value, :call
    end
  end

  test "admin section and screens render english chrome without proc leakage" do
    sign_in @user

    get "/admin/sections/agents"
    assert_response :success
    assert_includes response.body, "Agents admin"
    assert_includes response.body, "Who ran, what they tried, and how heavy the model calls were."
    assert_includes response.body, "Failed runs"
    assert_includes response.body, "Attempts this period"
    assert_includes response.body, "Tokens this period"
    assert_includes response.body, "Hungry agents"
    assert_includes response.body, "Last 4 weeks"
    refute_includes response.body, "#<Proc"

    get "/admin/screens/registered_agents"
    assert_response :success
    assert_includes response.body, "Agents"
    assert_includes response.body, "Including agents that have not run yet."
    refute_includes response.body, "#<Proc"

    get "/admin/screens/agent_runs"
    assert_response :success
    assert_includes response.body, "Runs"
    assert_includes response.body, "One attempt each. Steps lists the work in order."
    refute_includes response.body, "#<Proc"

    get "/admin/screens/agent_usage"
    assert_response :success
    assert_includes response.body, "Usage by agent"
    assert_includes response.body, "Attempts, outcomes, and average tokens."
    refute_includes response.body, "#<Proc"
  end

  test "enablement flash notice resolves through copy from en.yml" do
    sign_in @user
    RecordingStudioAgents::AgentEnablement.delete_all

    # Dummy boots with a host override on flashes.agent_off (rarely shown).
    post "/recording_studio_agents/admin/agents/page_librarian/turn_off", params: { version: 1 }
    assert_redirected_to "/admin/screens/registered_agents"
    follow_redirect!
    assert_includes response.body, "HOST turn-off notice for Page librarian."

    post "/recording_studio_agents/admin/agents/page_librarian/turn_on", params: { version: 1 }
    assert_redirected_to "/admin/screens/registered_agents"
    follow_redirect!
    assert_includes response.body, "Page librarian is on."
  ensure
    RecordingStudioAgents::AgentEnablement.delete_all
  end
end
