# frozen_string_literal: true

require "test_helper"

class AdminTableCssTest < ActiveSupport::TestCase
  test "admin table stylesheet uses FlatPack table tokens" do
    css = Rails.root.join("app/assets/stylesheets/admin_tables.css").read

    assert_includes css, "@layer utilities"
    assert_includes css, "var(--card-border-width)"
    assert_includes css, "var(--card-shadow)"
    assert_includes css, "html[data-theme~=\"rounded\"],"
    assert_includes css, "body[data-theme~=\"rounded\"]"
    assert_includes css, "--card-border-width: 1px"
    assert_includes css, "--card-border-color: var(--surface-border-color)"
    assert_includes css, "width: max-content"
    assert_includes css, "min-width: calc(100% + 1rem)"
    refute_includes css, "table-layout: fixed"
    refute_includes css, "min-width: 30rem"
    refute_includes css, "recording-studio-admin--screen-filters"
    refute_includes css, ".truncate"
    refute_includes css, ".sr-only"
    refute_includes css, "@keyframes"
    refute_includes css, "table-cell-skeleton"
    refute_includes css, "@apply"
    refute_includes css, "@import \"tailwindcss\""
  end

  test "admin layout links the table stylesheet after FlatPack variables" do
    layout = Rails.root.join("app/views/recording_studio/shared/_default_layout.html.erb").read
    variables_at = layout.index("flat_pack/variables")
    tables_at = layout.index("admin_tables")

    assert variables_at
    assert tables_at
    assert_operator variables_at, :<, tables_at
  end

  test "every layout orders cascade layers before FlatPack and Tailwind" do
    order = Rails.root.join("app/assets/stylesheets/cascade_layers.css").read
    assert_equal "@layer theme, base, components, utilities;\n", order

    %w[
      app/views/layouts/application.html.erb
      app/views/layouts/sidebar.html.erb
      app/views/recording_studio/shared/_default_layout.html.erb
    ].each do |relative|
      layout = Rails.root.join(relative).read
      layers_at = layout.index("cascade_layers")
      flatpack_at = layout.index("flat_pack/")
      tailwind_at = layout.index("tailwind")

      assert layers_at, relative
      assert_operator layers_at, :<, flatpack_at
      assert_operator layers_at, :<, tailwind_at
    end
  end
end
