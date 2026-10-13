# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"
require "yaml"

class HostLocaleOverrideTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  OVERRIDE_LOCALE = Rails.root.join("test/locales/agents_host_override.en.yml").to_s
  BOOT_HOST_LOCALE = Rails.root.join("config/locales/recording_studio_agents_boot_override.en.yml")
  BOOT_OVERRIDE_KEY = "recording_studio.agents.flashes.agent_off"

  setup do
    @user = User.find_or_create_by!(email: "admin-i18n-host@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    grant_accessible!(recording: RecordingStudio.root_recording_for(admin_root), actor: @user)
    @original_load_path = I18n.load_path.dup
    @original_backend = I18n.backend
    RecordingStudioAgents::AgentEnablement.delete_all
  end

  teardown do
    I18n.backend = @original_backend
    I18n.load_path.replace(@original_load_path)
    I18n.reload!
    RecordingStudioAgents::AgentEnablement.delete_all
  end

  test "host test-only locale override wins for the enablement on flash" do
    I18n.t("recording_studio.agents.flashes.agent_on")
    I18n.load_path |= [OVERRIDE_LOCALE]
    I18n.reload!
    host_on = flash_template(OVERRIDE_LOCALE, "agent_on")
    assert_equal host_on, I18n.t("recording_studio.agents.flashes.agent_on")

    sign_in @user
    post "/recording_studio_agents/admin/agents/page_librarian/turn_off", params: { version: 1 }
    follow_redirect!
    post "/recording_studio_agents/admin/agents/page_librarian/turn_on", params: { version: 1 }
    assert_redirected_to "/admin/screens/registered_agents"
    follow_redirect!

    assert_response :success
    assert_includes response.body, "HOST turn-on notice for Page librarian."
    refute_includes response.body, "Page librarian is on."
  end

  # Real-boot-order guard: host file under config/locales must win without any
  # test-time load_path mutation.
  test "boot-loaded host locale override wins for the enablement off flash" do
    host_off = flash_template(BOOT_HOST_LOCALE, "agent_off")
    assert File.exist?(BOOT_HOST_LOCALE), "expected boot host override at #{BOOT_HOST_LOCALE}"
    assert_equal host_off, YAML.safe_load_file(BOOT_HOST_LOCALE, aliases: true)
                               .dig("en", "recording_studio", "agents", "flashes", "agent_off")
    assert_equal host_off, I18n.t(BOOT_OVERRIDE_KEY)
    assert_equal @original_load_path, I18n.load_path,
                 "boot-order test must not mutate I18n.load_path"

    sign_in @user
    post "/recording_studio_agents/admin/agents/page_librarian/turn_off", params: { version: 1 }
    assert_redirected_to "/admin/screens/registered_agents"
    follow_redirect!

    assert_response :success
    assert_includes response.body, "HOST turn-off notice for Page librarian."
    refute_includes response.body, "Page librarian is off."
  end

  private

  def flash_template(path, key)
    YAML.safe_load_file(path, aliases: true)
        .fetch("en").fetch("recording_studio").fetch("agents").fetch("flashes").fetch(key)
  end
end
