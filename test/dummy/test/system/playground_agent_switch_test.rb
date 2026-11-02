# frozen_string_literal: true

require "application_system_test_case"

class PlaygroundAgentSwitchTest < ApplicationSystemTestCase
  include AccessibleTestHelpers

  self.use_transactional_tests = false

  setup do
    @user = User.find_or_initialize_by(email: "admin@admin.com")
    @user.password = "Password"
    @user.password_confirmation = "Password"
    @user.save!
    workspace = Workspace.find_or_create_by!(name: "Studio Workspace")
    root = RecordingStudio.root_recording_for(workspace)
    grant_accessible!(recording: root, actor: @user)
  end

  test "switching agents shows that agent's tools" do
    visit "/users/sign_in"
    page.execute_script("document.getElementById('new_user').requestSubmit()")
    assert_no_selector "h2", text: "Login", wait: 5

    visit "/playground"

    assert_selector "[data-playground-tools='page_librarian@1']", visible: true
    assert_text "Find page"

    select "Web researcher", from: "Agent"

    assert_selector "[data-playground-tools='web_researcher@1']", visible: true
    assert_text "Web search"
    assert_selector "[data-playground-tools='page_librarian@1']", visible: false
  end
end
