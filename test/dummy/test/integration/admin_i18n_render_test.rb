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

    get "/admin/screens/agent_runs/chart"
    assert_response :success
    assert_includes response.body, "Attempts"
    refute_includes response.body, "#<Proc"

    get "/admin/screens/agent_usage"
    assert_response :success
    assert_includes response.body, "Usage by agent"
    assert_includes response.body, "Attempts, outcomes, and average tokens."
    refute_includes response.body, "#<Proc"
  end

  test "admin dsl keeps screen and resource subtitles as english string literals" do
    assert_equal "Including agents that have not run yet.",
                 RecordingStudioAgents::Admin::AgentsScreen.subtitle
    assert_equal "One attempt each. Steps lists the work in order.",
                 RecordingStudioAgents::Admin::RunsScreen.subtitle
    assert_equal "Goals given to an agent.",
                 RecordingStudioAgents::Admin::TasksScreen.subtitle
    assert_equal "Attempts, outcomes, and average tokens.",
                 RecordingStudioAgents::Admin::UsageScreen.subtitle
    assert_equal "Pass, fail, or still deciding.",
                 RecordingStudioAgents::Admin::EvaluationsScreen.subtitle
    assert_equal "Turn an agent on or off.",
                 RecordingStudioAgents::Admin::AgentsResource.subtitle

    [
      RecordingStudioAgents::Admin::AgentsScreen.subtitle,
      RecordingStudioAgents::Admin::RunsScreen.subtitle,
      RecordingStudioAgents::Admin::AgentsResource.subtitle
    ].each do |subtitle|
      refute_respond_to subtitle, :call
    end
  end

  test "admin dsl titles resolve to english strings via evaluate" do
    context = RecordingStudioAdmin::Context.new(
      params: {},
      current_actor: @user,
      controller: nil,
      routes: nil,
      view_context: nil
    )

    section = RecordingStudioAgents::Admin::Section
    assert_equal "Agents admin", section.evaluate(section.title, context)
    assert_equal "Who ran, what they tried, and how heavy the model calls were.",
                 section.evaluate(section.subtitle, context)

    agents = RecordingStudioAgents::Admin::AgentsScreen
    assert_equal "Agents", agents.evaluate(agents.title, context)

    runs = RecordingStudioAgents::Admin::RunsScreen
    assert_equal "Runs", runs.evaluate(runs.title, context)
  end

  test "enablement flash notice stays byte-identical english" do
    sign_in @user
    RecordingStudioAgents::AgentEnablement.delete_all

    post "/recording_studio_agents/admin/agents/page_librarian/turn_off", params: { version: 1 }
    assert_redirected_to "/admin/screens/registered_agents"
    follow_redirect!
    assert_includes response.body, "Page librarian is off."

    post "/recording_studio_agents/admin/agents/page_librarian/turn_on", params: { version: 1 }
    assert_redirected_to "/admin/screens/registered_agents"
    follow_redirect!
    assert_includes response.body, "Page librarian is on."
  ensure
    RecordingStudioAgents::AgentEnablement.delete_all
  end
end
