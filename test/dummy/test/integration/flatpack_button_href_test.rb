# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class FlatpackButtonHrefTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.find_or_create_by!(email: "button-href@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    grant_accessible!(recording: RecordingStudio.root_recording_for(admin_root), actor: @user)
    sign_in @user
  end

  test "agents hub title buttons render as anchors with href" do
    get "/admin/sections/agents"

    assert_response :success
    assert_select "a[href=?]", "/admin/screens/registered_agents", text: "Agents"
    assert_select "a[href=?]", "/admin/screens/agent_runs", text: "Runs"
    assert_select "button", text: "Agents", count: 0
    assert_select "button", text: "Runs", count: 0
  end
end
