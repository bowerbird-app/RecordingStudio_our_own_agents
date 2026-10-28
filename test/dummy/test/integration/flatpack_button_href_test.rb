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
    @workspace = Workspace.find_or_create_by!(name: "Button Href Workspace")
    @root = RecordingStudio.root_recording_for(@workspace)
    grant_accessible!(recording: @root, actor: @user)
    sign_in @user
  end

  test "link-style button renders an anchor with href" do
    get root_path

    assert_response :success
    assert_select "a[href=?]", destroy_user_session_path, text: "Sign out"
    assert_select "button", text: "Sign out", count: 0
  end
end
