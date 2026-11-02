# frozen_string_literal: true

module RecordingStudioAgents
  module Admin
    module Queries
      module Scopes
        def agents
          RecordingStudioAgents.agents.all
        end

        def skills
          RecordingStudioAgents.skills.all
        end

        def skill_packs
          RecordingStudioAgents.skill_packs.all
        end

        def tasks(context:)
          Task.where(root_recording_id: visible_root_ids(context)).order(created_at: :desc)
        end

        def runs(context:)
          AgentRun.where(root_recording_id: visible_root_ids(context)).order(created_at: :desc)
        end

        def evaluations(context:)
          Evaluation.joins(:agent_run).where(
            recording_studio_agents_agent_runs: { root_recording_id: visible_root_ids(context) }
          ).order(created_at: :desc)
        end

        def recent_failed_runs(context:)
          runs(context: context).where(status: "failed").limit(5)
        end

        def visible_root_ids(context)
          actor = context.current_actor
          return [] if actor.blank? || !defined?(::RecordingStudioAccessible)

          ::RecordingStudioAccessible.root_recording_ids_for(actor: actor, minimum_role: :view)
        end

        def current_period(now: Time.current)
          LastFourWeeks.current_range(now: now)
        end

        def previous_period(now: Time.current)
          LastFourWeeks.previous_range(now: now)
        end

        def attempts_in_period(root_ids:, range:)
          AgentRun.where(root_recording_id: root_ids, created_at: range).count
        end

        def tokens_in_period(root_ids:, range:)
          return 0 unless ai_runs_available?

          AgentRun.where(root_recording_id: root_ids, created_at: range)
                  .joins(AI_JOIN)
                  .where("recording_studio_ai_runs.total_tokens IS NOT NULL")
                  .sum("recording_studio_ai_runs.total_tokens")
                  .to_i
        end

        def hungry_agents(root_ids:, range:, limit: HUNGRY_LIMIT)
          return [] unless ai_runs_available?

          totals = AgentRun.where(root_recording_id: root_ids, created_at: range)
                           .joins(AI_JOIN)
                           .where("recording_studio_ai_runs.total_tokens IS NOT NULL")
                           .group(:agent_key)
                           .sum("recording_studio_ai_runs.total_tokens")

          totals.sort_by { |key, tokens| [-tokens.to_i, key.to_s] }
                .first(limit)
                .filter_map do |key, tokens|
                  next unless tokens.to_i.positive?

                  { agent_key: key, tokens: tokens.to_i }
                end
        end

        def by_agent_rows(root_ids:, range:)
          runs = AgentRun.where(root_recording_id: root_ids, created_at: range).to_a
          ai_by_id = ai_runs_by_id(runs.map(&:recording_studio_ai_run_id))

          runs.group_by { |run| [run.agent_key, run.agent_version] }
              .map { |(key, version), group| build_by_agent_row(key, version, group, ai_by_id) }
              .sort_by { |row| [-row.attempts, row.agent_key.to_s, row.agent_version.to_i] }
        end

        def selected_time_range(context, screen:)
          value = context.filter_value(:date_range) if context.respond_to?(:filter_value)
          value ||= date_range_from_params(context, screen: screen)
          time_range_for(value) || current_period
        end

        def time_range_for(value)
          return unless value.respond_to?(:start_date) && value.respond_to?(:end_date)
          return unless value.start_date && value.end_date

          value.start_date.beginning_of_day..value.end_date.end_of_day
        end

        def distinct_agent_keys(context: nil)
          return [] unless AgentRun.table_exists?

          root_ids = visible_root_ids(context || filter_actor_context)
          return [] if root_ids.empty?

          AgentRun.where(root_recording_id: root_ids).distinct.order(:agent_key).pluck(:agent_key)
        rescue *RecordingStudioAgents.lookup_errors
          []
        end

        def ai_runs_available?
          klass = ai_run_class
          return false unless klass
          return false unless klass.respond_to?(:table_exists?)

          klass.table_exists?
        rescue *RecordingStudioAgents.lookup_errors
          false
        end

        def ai_run_class
          return @ai_run_class if instance_variable_defined?(:@ai_run_class) && !@ai_run_class.nil?
          return RecordingStudioAI::Run if defined?(RecordingStudioAI::Run)

          nil
        end

        def use_ai_run_class!(klass)
          @ai_run_class = klass
        end

        def reset_ai_run_class!
          remove_instance_variable(:@ai_run_class) if instance_variable_defined?(:@ai_run_class)
        end

        def ai_run_for(id)
          return if id.blank? || !ai_runs_available?

          cache = Thread.current[:recording_studio_agents_ai_runs] ||= {}
          return cache[id] if cache.key?(id)

          cache[id] = ai_run_class.find_by(id: id)
        end

        def ai_runs_by_id(ids)
          clean_ids = ids.compact.uniq
          return {} if clean_ids.empty? || !ai_runs_available?

          ai_run_class.where(id: clean_ids).index_by(&:id).tap do |found|
            cache = Thread.current[:recording_studio_agents_ai_runs] ||= {}
            found.each { |id, run| cache[id] = run }
          end
        end

        def clear_ai_run_cache!
          Thread.current[:recording_studio_agents_ai_runs] = nil
        end
      end
    end
  end
end
