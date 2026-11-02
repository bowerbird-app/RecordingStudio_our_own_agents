# frozen_string_literal: true

require_relative "runtime/planning"
require_relative "runtime/decisions"
require_relative "runtime/performance"
require_relative "runtime/records"

module RecordingStudioAgents
  class Runtime
    DELIVER_FOLLOWUP_REASONS = %w[deliver_below_threshold uncertain missing_choice].freeze

    def initialize(program:, ledger:, invocation:)
      @program = program
      @ledger = ledger
      @invocation = invocation
    end

    def call(request:, run:, lease_token:, plan: nil)
      state = WorkingState.load(run.try(:working_state_json))
      state, = StateDelta.apply(state, { "set_goal" => request.task_input.goal }) if state.goal.to_s.empty?
      menu = ActionMenu.new.restore_terminal(state.data["candidate_index"])
      if plan && state.counter("reasoner_calls").zero?
        state, menu = accept_plan(request, run, lease_token, state, plan, replan: false)
      end

      guard = 0
      loop do
        guard += 1
        if guard > configuration.maximum_steps + configuration.maximum_reasoner_calls + 5
          return fail_run(run, lease_token, "maximum_steps", false)
        end

        @ledger.renew_lease!(run: run, lease_token: lease_token)
        run.agent_steps.reset
        state = shrink(request, run, lease_token, state)
        resumed = resume_open_step(request, run, lease_token, state)
        return resumed if resumed.is_a?(Results::Blocked) || resumed.is_a?(Results::Failed)

        state, menu = resumed if resumed.is_a?(Array)

        steps = run.agent_steps.count
        if Signals.over_budget?(state: state, steps: steps, configuration: configuration, started_at: run.started_at)
          code = Signals.budget_code(
            state: state, steps: steps, configuration: configuration, started_at: run.started_at
          )
          return fail_run(run, lease_token, code, false)
        end

        if menu.actionable.empty?
          followed = follow_empty_menu(request, run, lease_token, state, menu)
          return followed unless followed.is_a?(Array)

          state, menu = followed
          next
        end

        if Signals.repeated_digest?(state) || state.data["no_progress_streak"].to_i >= Signals::REPEAT_LIMIT
          @ledger.note_activity!(run: run, lease_token: lease_token, kind: "stuck_detected",
                                 data: { "sequence" => steps })
          if state.counter("replans") >= configuration.maximum_replans
            return fail_run(run, lease_token, "maximum_replans",
                            false)
          end

          state, menu = replan(request, run, lease_token, state, menu)
          next
        end

        if state.criteria_met? && menu.actionable.any?(&:deliver?)
          return finish(request, run, lease_token, state, menu.actionable.find(&:deliver?))
        end

        verdict, state = decide(request, run, lease_token, state, menu, steps)
        if verdict.fail?
          return fail_run(run, lease_token, "decision_failed",
                          verdict.probabilities["retryable"] == true)
        end

        if verdict.reason?
          followed = follow_open_deliver(request, run, lease_token, state, menu, verdict)
          unless followed.nil?
            return followed unless followed.is_a?(Array)

            state, menu = followed
            next
          end
          if state.counter("replans") >= configuration.maximum_replans
            return fail_run(run, lease_token, "maximum_replans",
                            false)
          end

          state, menu = replan(request, run, lease_token, state, menu)
          next
        end
        return finish(request, run, lease_token, state, menu.fetch(verdict.candidate_id)) if verdict.finish?
        return handoff(run, lease_token, menu.fetch(verdict.candidate_id), verdict) if verdict.handoff?

        acted = perform(request, run, lease_token, state, menu, verdict)
        return acted if acted.is_a?(Results::Blocked) || acted.is_a?(Results::Failed)

        state, menu = acted
      end
    end

    include Planning
    include Decisions
    include Performance
    include Records
  end
end
