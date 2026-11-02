# frozen_string_literal: true

module RecordingStudioAgents
  module Admin
    module Queries
      module Cells
        def agent_name_cell(row, context)
          key = row.try(:agent_key) || row.key
          version = row.try(:agent_version) || row.version
          label = row.try(:name).presence || agent_name(key, version: version)
          admin_link(label, screen_href(context, "registered_agent", agent_key: key, version: version))
        end

        def enabled_badge_options(enabled)
          if enabled
            { text: "On", style: :success, size: :sm }
          else
            { text: "Off", style: :default, size: :sm }
          end
        end

        def agent_enablement_href(row, action, context = nil)
          helper_name = :"admin_#{action}_agent_path"
          proxy = enablement_route_proxy(context)
          return unless proxy.respond_to?(helper_name)

          proxy.public_send(helper_name, row.key, version: row.version)
        end

        def status_badge_options(status)
          STATUS_BADGES.fetch(status.to_s) { { text: status.to_s.humanize, style: :default } }.merge(size: :sm)
        end

        def token_total(row)
          step_ids = step_ai_run_ids(row)
          return ai_run_for(row.recording_studio_ai_run_id)&.total_tokens if step_ids.empty?

          (step_ids + [row.recording_studio_ai_run_id]).compact.uniq.sum do |id|
            ai_run_for(id)&.total_tokens.to_i
          end
        end

        def objective_cell(row)
          text = working_state_for(row)&.current_objective
          text.presence || BLANK
        end

        def counter_cell(row, name)
          state = working_state_for(row)
          return BLANK unless state

          state.counter(name).to_s
        end

        def stuck_cell(row)
          state = working_state_for(row)
          return BLANK unless state

          state.data["no_progress_streak"].to_i >= Signals::REPEAT_LIMIT ? "Stuck" : "Moving"
        end

        def working_state_for(row)
          return unless row.respond_to?(:has_attribute?) && row.has_attribute?(:working_state_json)
          return if row.working_state_json.blank?

          WorkingState.load(row.working_state_json)
        rescue ContractError
          nil
        end

        def step_ai_run_ids(row)
          return [] unless row.respond_to?(:agent_steps)
          return [] unless row.agent_steps.exists?

          row.agent_steps.pluck(:recording_studio_ai_run_id).compact
        rescue *RecordingStudioAgents.lookup_errors
          []
        end

        def tools_cell(row, context)
          state = working_state_for(row)
          return state.counter("tool_actions").to_s if state && row.respond_to?(:agent_steps) && row.agent_steps.exists?

          ai_run = ai_run_for(row.recording_studio_ai_run_id)
          return BLANK if ai_run.nil?

          count = ai_run.custom_tool_invocation_count.to_i
          return count.to_s if count.zero?

          href = screen_href(context, "tool_calls", run_id: ai_run.id)
          return delimited_number(count) if href.blank?

          ActionController::Base.helpers.link_to(
            delimited_number(count),
            href,
            class: "text-(--color-primary-background-color)",
            data: { turbo_frame: "_top" }
          )
        end

        def ai_run_cell(row, context)
          id = row.recording_studio_ai_run_id
          return BLANK if id.blank?

          href = screen_href(context, "ai_calls", search: id)
          return id.to_s if href.blank?

          ActionController::Base.helpers.link_to(
            id.to_s,
            href,
            class: "text-(--color-primary-background-color)",
            data: { turbo_frame: "_top" }
          )
        end

        def labeled_references(refs, catalog)
          return NONE if refs.blank?

          refs.map { |ref| labeled_reference(ref, catalog) }.join(", ")
        end

        def linked_skill_references(refs, context)
          linked_references(refs, RecordingStudioAgents.skills.all, context, "registered_skill", :skill_key)
        end

        def linked_tool_references(refs, context)
          catalog = defined?(::RecordingStudioAI) ? RecordingStudioAI.tools.all : []
          linked_references(refs, catalog, context, "registered_tool", :tool_key)
        end

        def linked_references(refs, catalog, context, screen_key, key_param)
          return NONE if refs.blank?

          ActionController::Base.helpers.safe_join(
            refs.map { |ref| linked_reference(ref, catalog, context, screen_key, key_param) },
            ", "
          )
        end

        def linked_reference(ref, catalog, context, screen_key, key_param)
          label = labeled_reference(ref, catalog)
          return label unless context

          admin_link(label, screen_href(context, screen_key, key_param => ref.key, version: ref.version))
        end

        def labeled_reference(ref, catalog)
          item = catalog_item(catalog, key: ref.key, version: ref.version)
          item&.name.presence || ref.key
        end

        def admin_link(label, href)
          return label if href.blank?

          ActionController::Base.helpers.link_to(
            label,
            href,
            class: "text-(--color-primary-background-color)",
            data: { turbo_frame: "_top" }
          )
        end

        def show_subtitle(item, missing:, fallback:)
          return missing unless item

          item.description.presence || fallback
        end

        def presence_or_none(value)
          value.to_s.strip.presence || NONE
        end

        def tool_inputs_label(tool)
          names = Array(tool.parameters).filter_map { |parameter| parameter[:name] || parameter["name"] }
          names.presence&.join(", ") || NONE
        end

        def catalog_item(catalog, key:, version:)
          key = key.to_s
          exact = catalog.find { |item| item.key.to_s == key && item.version == version }
          return exact if exact

          catalog.select { |item| item.key.to_s == key }.max_by(&:version)
        end

        def request_param(context, key)
          params = context.respond_to?(:params) ? context.params : nil
          return if params.blank?

          params[key] || params[key.to_s] || params[key.to_sym]
        end

        def build_by_agent_row(key, version, group, ai_by_id)
          ai_rows = group.filter_map { |run| ai_by_id[run.recording_studio_ai_run_id] }

          ByAgentRow.new(
            agent_key: key,
            agent_version: version,
            attempts: group.size,
            succeeded: count_status(group, "succeeded"),
            failed: count_status(group, "failed"),
            waiting: group.count { |run| WAITING_STATUSES.include?(run.status) },
            avg_tokens: average(ai_rows.filter_map(&:total_tokens)),
            avg_latency_ms: average(ai_rows.filter_map(&:latency_ms)),
            avg_tools: average(ai_rows.filter_map(&:custom_tool_invocation_count)),
            ai_sample_count: ai_rows.size
          )
        end

        def count_status(group, status)
          group.count { |run| run.status == status }
        end

        def average(values)
          numbers = values.compact
          return if numbers.empty?

          (numbers.sum.to_f / numbers.size).round
        end

        def date_range_from_params(context, screen:)
          filter = Array(screen.filters).find { |item| item.key == :date_range }
          return unless filter

          params = context.respond_to?(:params) ? context.params : {}
          filter.normalize(params || {})
        end

        def filter_actor_context
          Struct.new(:current_actor).new(current_filter_actor)
        end

        def current_filter_actor
          return unless defined?(::Current) && Current.respond_to?(:actor)

          Current.actor
        rescue *RecordingStudioAgents.lookup_errors
          nil
        end

        def enablement_route_proxy(context)
          controller = context&.controller
          return controller.recording_studio_agents if controller.respond_to?(:recording_studio_agents)

          RecordingStudioAgents::Engine.routes.url_helpers
        end

        def compact_thousands(count)
          "#{trimmed_units(count / 1000.0)}k"
        end

        def compact_millions(count)
          "#{trimmed_units(count / 1_000_000.0)}M"
        end

        def trimmed_units(value)
          rounded = value.round(1)
          (rounded % 1).zero? ? rounded.to_i : rounded
        end
      end
    end
  end
end
