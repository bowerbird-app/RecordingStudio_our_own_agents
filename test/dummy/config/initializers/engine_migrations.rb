# frozen_string_literal: true

# Upstream engine migrations are not copied into db/migrate. Schema load records
# one version and leaves later engine migrations pending. A full migrate also
# trips on duplicate versions shared by older gems, so boot applies only the
# engine migrations newer than the loaded schema. This does not write schema.rb.
module DummyEngineMigrations
  ENGINES = [
    "RecordingStudioAI::Engine",
    "RecordingStudioAccessible::Engine",
    "RecordingStudioLogs::Engine"
  ].freeze

  def self.apply!
    return unless Rails.env.local?

    pool = ActiveRecord::Base.connection_pool
    begin
      return unless pool.schema_migration.table_exists?
    rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished
      return
    end

    schema_version = pool.schema_migration.integer_versions.max.to_i
    return if schema_version.zero?

    paths = ENGINES.filter_map { |name| migration_path(name) }
    context = ActiveRecord::MigrationContext.new(paths, pool.schema_migration, pool.internal_metadata)
    ran = context.get_all_versions
    pending = context.migrations.select { |migration| migration.version > schema_version && ran.exclude?(migration.version) }
    return if pending.empty?

    proxies = pending.map { |migration| proxy_for(migration) }
    ActiveRecord::Migration.verbose = false
    ActiveRecord.dump_schema_after_migration = false
    ActiveRecord::Migrator.new(:up, proxies, pool.schema_migration, pool.internal_metadata).migrate
  end

  def self.proxy_for(migration)
    ActiveRecord::MigrationProxy.new(class_name(migration.filename), migration.version, migration.filename, migration.scope)
  end

  def self.class_name(filename)
    File.foreach(filename) do |line|
      matched = line.match(/\Aclass ([A-Z][A-Za-z0-9_]*)\s*</)
      return matched[1] if matched
    end

    raise "No migration class in #{filename}"
  end

  def self.migration_path(engine_name)
    path = engine_name.constantize.root.join("db/migrate")
    path.to_s if path.directory?
  end
end

DummyEngineMigrations.apply!
