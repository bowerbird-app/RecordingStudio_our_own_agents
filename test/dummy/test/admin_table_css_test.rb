# frozen_string_literal: true

require "test_helper"

class AdminTableCssTest < ActiveSupport::TestCase
  test "admin table stylesheet uses FlatPack table tokens" do
    css = Rails.root.join("app/assets/stylesheets/admin_tables.css").read

    assert_includes css, "table.fp-table"
    assert_includes css, "var(--table-border-color)"
    assert_includes css, "var(--table-header-background-color)"
    assert_includes css, "var(--table-padding-x)"
    assert_includes css, "var(--table-row-hover-background-color)"
    assert_includes css, "recording-studio-admin--screen-filters"
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
end
