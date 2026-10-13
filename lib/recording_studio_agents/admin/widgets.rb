# frozen_string_literal: true

module RecordingStudioAgents
  module Admin
    module Widgets
      FAILED_RUNS = RecordingStudioAdmin::Widget.new("widgets.agents.failed_runs") do
        type :list
        title { Copy.t("admin.widgets.failed_runs.title") }
        info do
          Copy.t("admin.widgets.failed_runs.info")
        end
        hide_change
        hide_period
        items do |context|
          Queries.recent_failed_runs(context: context).map do |run|
            {
              text: "#{run.agent_key} · #{run.failure_code || 'failed'}",
              href: Queries.screen_href(context, "agent_runs", status: "failed")
            }
          end
        end
      end

      ATTEMPTS_THIS_PERIOD = RecordingStudioAdmin::Widget.new("widgets.agents.attempts_this_period") do
        type :number
        title { Copy.t("admin.widgets.attempts_this_period.title") }
        info do
          Copy.t("admin.widgets.attempts_this_period.info")
        end
        metadata { { period_label: Copy.t("admin.widgets.period_label") } }
        value do |context|
          root_ids = Queries.visible_root_ids(context)
          Queries.delimited_number(
            Queries.attempts_in_period(root_ids: root_ids, range: Queries.current_period)
          )
        end
        change do |context|
          root_ids = Queries.visible_root_ids(context)
          Queries.percentage_change_label(
            current: Queries.attempts_in_period(root_ids: root_ids, range: Queries.current_period),
            previous: Queries.attempts_in_period(root_ids: root_ids, range: Queries.previous_period)
          )
        end
        change_good_when :neutral
        link_to { |context| context.admin_screen_path("agent_runs") }
      end

      TOKENS_THIS_PERIOD = RecordingStudioAdmin::Widget.new("widgets.agents.tokens_this_period") do
        type :number
        title { Copy.t("admin.widgets.tokens_this_period.title") }
        info do
          Copy.t("admin.widgets.tokens_this_period.info")
        end
        metadata { { period_label: Copy.t("admin.widgets.period_label") } }
        value do |context|
          root_ids = Queries.visible_root_ids(context)
          Queries.delimited_number(
            Queries.tokens_in_period(root_ids: root_ids, range: Queries.current_period)
          )
        end
        change do |context|
          root_ids = Queries.visible_root_ids(context)
          Queries.percentage_change_label(
            current: Queries.tokens_in_period(root_ids: root_ids, range: Queries.current_period),
            previous: Queries.tokens_in_period(root_ids: root_ids, range: Queries.previous_period)
          )
        end
        change_good_when :down
        link_to { |context| context.admin_screen_path("agent_usage") }
      end

      HUNGRY_AGENTS = RecordingStudioAdmin::Widget.new("widgets.agents.hungry_agents") do
        type :list
        title { Copy.t("admin.widgets.hungry_agents.title") }
        info do
          Copy.t("admin.widgets.hungry_agents.info")
        end
        hide_change
        metadata { { period_label: Copy.t("admin.widgets.period_label") } }
        items do |context|
          root_ids = Queries.visible_root_ids(context)
          Queries.hungry_agents(root_ids: root_ids, range: Queries.current_period).map do |row|
            {
              text: Queries.hungry_label(agent_key: row[:agent_key], tokens: row[:tokens]),
              href: Queries.screen_href(context, "agent_runs", agent_key: row[:agent_key])
            }
          end
        end
      end
    end
  end
end
