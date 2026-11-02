# frozen_string_literal: true

RecordingStudioAdmin.configure do |config|
  config.default_mount_path = "/admin"
  config.authentication_method = :authenticate_user!
  config.current_actor_method = :current_user
  config.async_widgets.enabled = false

  config.layout = "recording_studio/default_layout"
  # Staff screens stay off the switched product workspace. A nil return wins
  # over Root Switchable. Admin config is the only owner of that nil root.
  config.current_root_recording_resolver = ->(_context) { nil }
  config.access_recording_resolver = lambda do |_context|
    admin_root = AdminRoot.find_by(name: "Admin")
    next unless admin_root

    RecordingStudio::Recording.where(
      RecordingStudio::Recording.recording_studio_trashable_kept_sql
    ).find_by(recordable: admin_root)
  end
  config.site_admin_recording_resolver = config.access_recording_resolver
end

Rails.application.config.to_prepare do
  # app/admin is outside Zeitwerk. Admin 2.8.1 has no setting that reloads a
  # host section class, so this prepare still drops RootSection and loads the
  # file. register_section is the public registration API.
  if defined?(AdminScreens::RootSection)
    AdminScreens.send(:remove_const, :RootSection)
  end
  load Rails.root.join("app/admin/root/section.rb")
  RecordingStudioAdmin.register_section(AdminScreens::RootSection)
end
