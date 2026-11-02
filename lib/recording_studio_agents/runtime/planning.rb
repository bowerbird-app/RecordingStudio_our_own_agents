# frozen_string_literal: true

module RecordingStudioAgents
  class Runtime
    module Planning
      private

      def configuration
        RecordingStudioAgents.configuration
      end

      def accept_plan(request, run, lease_token, state, response, replan:)
        data = response.structured_data.is_a?(Hash) ? response.structured_data.stringify_keys : {}
        menu = ActionMenu.admit(
          data["action_candidates"],
          program: @program,
          refused_digests: state.data["refused_digests"]
        )
        state, compacted = StateDelta.apply(state, {
                                              "replace_plan" => Array(data["plan"]),
                                              "replace_criteria" => Array(data["success_criteria"]),
                                              "set_current_objective" => data["current_objective"],
                                              "replace_candidate_index" => menu.index,
                                              "increment" => { "reasoner_calls" => 1, "replans" => (replan ? 1 : 0) }
                                            })
        state, menu, fills = supply_arguments(run, lease_token, state, menu)
        state, = StateDelta.apply(state, { "replace_candidate_index" => menu.index })
        state = remember_compaction(state, compacted)
        state = shrink(request, run, lease_token, state)
        @ledger.checkpoint!(
          run: run, lease_token: lease_token, state: state,
          step: step_attributes(
            run, "completed", "reason", nil,
            observation_summary: data["current_objective"].to_s,
            ai_run_id: response.try(:run)&.id
          ).merge(record_json: plan_record(data)),
          activities: replan ? [%w[replanned reasoner_requested]] : [%w[reasoner_requested]]
        )
        remember_argument_fills(run, lease_token, state, fills)
        if compacted
          @ledger.note_activity!(run: run, lease_token: lease_token, kind: "compacted",
                                 data: { "sequence" => run.agent_steps.maximum(:sequence).to_i })
        end
        [state, menu]
      end

      def supply_arguments(run, lease_token, state, menu)
        fills = []
        menu.tools.each do |candidate|
          next unless arguments_invalid?(candidate)

          tool = tool_definition(candidate)
          if tool.nil? || state.counter("reasoner_calls") >= configuration.maximum_reasoner_calls
            menu.consume(candidate.id)
            next
          end

          response = Ai.fill_arguments(
            invocation: @invocation, run: run, lease_token: lease_token,
            prompt: ContextBuilder.for_arguments(state: state, candidate: candidate, tool: tool),
            schema: tool.json_schema,
            suffix: "arguments-#{state.counter('reasoner_calls') + 1}"
          )
          state, = StateDelta.apply(state, { "increment" => { "reasoner_calls" => 1 } })
          arguments = accepted_arguments(tool, response)
          if arguments
            updated = candidate.with_arguments(arguments)
            menu.add(updated)
            fills << argument_fill(updated, response, "completed", "Filled in the missing details.")
          else
            menu.consume(candidate.id)
            fills << argument_fill(candidate, response, "failed", "The details are still missing.")
          end
        end
        [state, menu, fills]
      end

      def arguments_invalid?(candidate)
        tool = tool_definition(candidate)
        return false unless tool

        tool.validate_arguments!(candidate.arguments)
        false
      rescue RecordingStudioAI::Errors::ContractValidationError
        true
      end

      def accepted_arguments(tool, response)
        return if response.respond_to?(:error) && response.error

        data = response.respond_to?(:structured_data) ? response.structured_data : nil
        return unless data.is_a?(Hash)

        tool.validate_arguments!(data)
      rescue RecordingStudioAI::Errors::ContractValidationError
        nil
      end

      def argument_fill(candidate, response, status, summary)
        {
          status: status,
          candidate: candidate,
          summary: summary,
          ai_run: response.try(:run)
        }
      end

      def remember_argument_fills(run, lease_token, state, fills)
        fills.each do |fill|
          run.reload
          candidate = fill[:candidate]
          @ledger.checkpoint!(
            run: run, lease_token: lease_token, state: state,
            step: step_attributes(
              run, fill[:status], "arguments", candidate.id,
              tool_key: candidate.tool_key, tool_version: candidate.tool_version,
              argument_digest: candidate.argument_digest,
              observation_summary: fill[:summary],
              ai_run_id: fill[:ai_run]&.id
            ),
            activities: [%w[reasoner_requested]]
          )
          next unless fill[:ai_run]

          @ledger.attach_ai_run!(run: run, lease_token: lease_token, ai_run: fill[:ai_run])
        end
      end

      def follow_empty_menu(request, run, lease_token, state, menu)
        return finish(request, run, lease_token, state, nil) if state.criteria_met?
        return follow_observations(request, run, lease_token, state, menu) if observations_present?(state)

        replan_or_stop(request, run, lease_token, state, menu)
      end

      def follow_observations(request, run, lease_token, state, menu)
        verdict, state = decide_if_answered(request, run, lease_token, state)
        if verdict.fail?
          return fail_run(run, lease_token, "decision_failed",
                          verdict.probabilities["retryable"] == true)
        end
        return finish(request, run, lease_token, state, nil) if verdict.finish?
        return ask_for_next_actions(request, run, lease_token, state, menu) if fresh_actions?(state, verdict)

        replan_or_stop(request, run, lease_token, state, menu)
      end

      def ask_for_next_actions(request, run, lease_token, state, menu)
        if state.counter("reasoner_calls") >= configuration.maximum_reasoner_calls
          return fail_run(run, lease_token, "maximum_reasoner_calls", false)
        end

        next_actions(request, run, lease_token, state, menu)
      end

      def replan_or_stop(request, run, lease_token, state, menu)
        if state.counter("replans") >= configuration.maximum_replans
          return fail_run(run, lease_token, "maximum_replans", false)
        end
        if state.counter("reasoner_calls") >= configuration.maximum_reasoner_calls
          return fail_run(run, lease_token, "maximum_reasoner_calls", false)
        end

        replan(request, run, lease_token, state, menu)
      end

      def fresh_actions?(state, verdict)
        return false if Signals.hard_stuck?(state)

        verdict.probabilities["stuck"].to_f < configuration.stuck_probability
      end

      def follow_open_deliver(request, run, lease_token, state, menu, verdict)
        return unless open_deliver?(state, menu, verdict)

        deliver = menu.actionable.find(&:deliver?)
        return finish(request, run, lease_token, state, deliver) if state.data["deliver_followup"]

        marked, = StateDelta.apply(state, { "set_deliver_followup" => true })
        ask_to_close(request, run, lease_token, marked)
      end

      def open_deliver?(state, menu, verdict)
        return false if state.criteria_met?
        return false unless DELIVER_FOLLOWUP_REASONS.include?(verdict.reason)

        deliver_only?(menu)
      end

      def deliver_only?(menu)
        actions = menu.actionable
        actions.any?(&:deliver?) && actions.all?(&:deliver?)
      end

      def ask_to_close(request, run, lease_token, state)
        if state.counter("reasoner_calls") >= configuration.maximum_reasoner_calls
          return finish(request, run, lease_token, state, nil)
        end

        next_actions(
          request, run, lease_token, state, ActionMenu.new,
          prompt: ContextBuilder.for_closing_actions(
            state: state, menu: ActionMenu.new, signals: signal_lines(state, run)
          ),
          suffix: "close-#{state.counter('reasoner_calls') + 1}"
        )
      end

      def next_actions(request, run, lease_token, state, menu, prompt: nil, suffix: nil)
        prompt ||= ContextBuilder.for_next_actions(state: state, menu: menu, signals: signal_lines(state, run))
        suffix ||= "next-#{state.counter('reasoner_calls') + 1}"
        response = Ai.next_actions(
          invocation: @invocation, run: run, lease_token: lease_token, prompt: prompt,
          suffix: suffix
        )
        if response.respond_to?(:run) && response.run
          @ledger.attach_ai_run!(run: run, lease_token: lease_token, ai_run: response.run)
        end
        unless response.respond_to?(:error) ? response.error.nil? : true
          raise response.error if response.error.respond_to?(:message)

          raise ContractError, "next actions failed"
        end

        accept_next(request, run, lease_token, state, response)
      end

      def accept_next(request, run, lease_token, state, response)
        data = response.structured_data.is_a?(Hash) ? response.structured_data.stringify_keys : {}
        menu = ActionMenu.admit(
          data["action_candidates"],
          program: @program,
          refused_digests: state.data["refused_digests"]
        )
        delta = {
          "replace_candidate_index" => menu.index,
          "increment" => { "reasoner_calls" => 1 }
        }
        delta["set_current_objective"] = data["current_objective"] if data["current_objective"].present?
        state, compacted = StateDelta.apply(state, delta)
        state, menu, fills = supply_arguments(run, lease_token, state, menu)
        state, = StateDelta.apply(state, { "replace_candidate_index" => menu.index })
        state = remember_compaction(state, compacted)
        state = shrink(request, run, lease_token, state)
        @ledger.checkpoint!(
          run: run, lease_token: lease_token, state: state,
          step: step_attributes(
            run, "completed", "reason", nil,
            observation_summary: "Asked for the next actions.",
            ai_run_id: response.try(:run)&.id
          ).merge(record_json: action_record(menu)),
          activities: [%w[reasoner_requested]]
        )
        remember_argument_fills(run, lease_token, state, fills)
        [state, menu]
      end

      def replan(request, run, lease_token, state, menu)
        prompt = ContextBuilder.for_reasoner(state: state, menu: menu, signals: signal_lines(state, run))
        response = Ai.plan(invocation: @invocation, run: run, lease_token: lease_token, prompt: prompt,
                           suffix: "reason-#{state.counter('reasoner_calls') + 1}")
        if response.respond_to?(:run) && response.run
          @ledger.attach_ai_run!(run: run, lease_token: lease_token,
                                 ai_run: response.run)
        end
        unless response.respond_to?(:error) ? response.error.nil? : true
          raise response.error if response.error.respond_to?(:message)

          raise ContractError, "replanning failed"
        end

        accept_plan(request, run, lease_token, state, response, replan: state.counter("reasoner_calls").positive?)
      end
    end
  end
end
