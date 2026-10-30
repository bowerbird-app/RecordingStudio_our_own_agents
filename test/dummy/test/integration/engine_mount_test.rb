# frozen_string_literal: true

require "test_helper"

class EngineMountTest < ActionDispatch::IntegrationTest
  test "the engine mount has no template home route" do
    get "/recording_studio_agents"

    assert_response :not_found
  end
end
