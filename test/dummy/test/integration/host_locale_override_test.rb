# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class HostLocaleOverrideTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  HOST_SECTION_TITLE = "HOST Agents admin"
  HOST_FAILED_RUNS_INFO = "HOST last attempts that did not finish."
  OVERRIDE_LOCALE = Rails.root.join("test/locales/agents_host_override.en.yml").to_s
  BOOT_HOST_LOCALE = Rails.root.join("config/locales/recording_studio_agents_boot_override.en.yml")
  BOOT_OVERRIDE_KEY = "recording_studio.agents.admin.widgets.failed_runs.info"

  setup do
    @user = User.find_or_create_by!(email: "admin-i18n-host@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    grant_accessible!(recording: RecordingStudio.root_recording_for(admin_root), actor: @user)
    @original_load_path = I18n.load_path.dup
    @original_backend = I18n.backend
  end

  teardown do
    I18n.backend = @original_backend
    I18n.load_path.replace(@original_load_path)
    I18n.reload!
  end

  test "host test-only locale override wins for the section title on a real page" do
    I18n.t("recording_studio.agents.admin.section.title")
    I18n.load_path |= [OVERRIDE_LOCALE]
    I18n.reload!
    assert_equal HOST_SECTION_TITLE, I18n.t("recording_studio.agents.admin.section.title")

    sign_in @user
    get "/admin/sections/agents"

    assert_response :success
    assert_includes response.body, HOST_SECTION_TITLE
    refute_includes response.body, ">Agents admin<"
  end

  # Real-boot-order guard: host file under config/locales must win without any
  # test-time load_path mutation.
  test "boot-loaded host locale override wins for failed-runs widget info on a real page" do
    assert File.exist?(BOOT_HOST_LOCALE), "expected boot host override at #{BOOT_HOST_LOCALE}"
    assert_includes File.read(BOOT_HOST_LOCALE), HOST_FAILED_RUNS_INFO
    assert_equal HOST_FAILED_RUNS_INFO, I18n.t(BOOT_OVERRIDE_KEY)
    assert_equal @original_load_path, I18n.load_path,
                 "boot-order test must not mutate I18n.load_path"

    sign_in @user
    get "/admin/sections/agents"

    assert_response :success
    assert_includes response.body, HOST_FAILED_RUNS_INFO
    refute_includes response.body,
                    "The last attempts that did not finish. Open Runs if you need to retry from the host."
    assert_includes response.body, "Failed runs"
  end
end
