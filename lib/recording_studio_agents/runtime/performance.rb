# frozen_string_literal: true

module RecordingStudioAgents
  class Runtime
    module Performance
      private

      def perform(request, run, lease_token, state, menu, verdict)
        candidate = menu.fetch(verdict.candidate_id)
        sequence = next_sequence(run)
        repeatable = repeatable_tool?(candidate)
        @ledger.checkpoint!(
          run: run, lease_token: lease_token, state: state,
          step: step_attributes(
            run, "started", "tool", candidate.id,
            tool_key: candidate.tool_key, tool_version: candidate.tool_version,
            argument_digest: candidate.argument_digest, repeatable: repeatable,
            sequence: sequence, controller_outcome: verdict.probabilities.merge("reason" => verdict.reason)
          ),
          activities: [%w[step_started]]
        )
        begin
          performance = Ai.perform_tool(
            invocation: @invocation, run: run, candidate: candidate, sequence: sequence, resume: false
          )
        rescue ConfigurationError => e
          return stop_for_tool_error(run, lease_token, state, sequence, e.message)
        end
        apply_performance(request, run, lease_token, state, menu, candidate, sequence, performance, verdict)
      end

      def resume_open_step(request, run, lease_token, state)
        step = run.agent_steps.order(:sequence).last
        return unless step

        if step.status == "awaiting_confirmation"
          candidate = candidate_from_step(step)
          begin
            performance = Ai.perform_tool(
              invocation: @invocation, run: run, candidate: candidate, sequence: step.sequence, resume: true
            )
          rescue ConfigurationError => e
            return stop_for_tool_error(run, lease_token, state, step.sequence, e.message)
          end
          menu = ActionMenu.new.restore_terminal(state.data["candidate_index"])
          return apply_performance(request, run, lease_token, state, menu, candidate, step.sequence, performance, nil)
        end

        return unless step.status == "started" && step.action_type == "tool"

        stored = replay_stored_tool(run, step)
        if stored
          menu = ActionMenu.new.restore_terminal(state.data["candidate_index"])
          return apply_performance(
            request, run, lease_token, state, menu, candidate_from_step(step), step.sequence, stored, nil
          )
        end

        close_started_step(run, lease_token, state, step)
      end

      def replay_stored_tool(run, step)
        request_id = "#{Ai.request_id_for(run)}:tool:#{step.sequence}"
        return unless Ai.find_run(request_id: request_id)

        Ai.perform_tool(
          invocation: @invocation, run: run, candidate: candidate_from_step(step),
          sequence: step.sequence, resume: false
        )
      rescue RecordingStudioAI::Errors::ContractValidationError
        nil
      end

      def apply_performance(request, run, lease_token, state, menu, candidate, sequence, performance, verdict)
        if performance.awaiting_confirmation?
          @ledger.checkpoint!(
            run: run, lease_token: lease_token, state: state,
            step: { sequence: sequence, status: "awaiting_confirmation" },
            activities: []
          )
          @ledger.commit_blocked!(run: run, lease_token: lease_token)
          return Results::Blocked.new(run: run.reload)
        end

        unless performance.success?
          summary = performance.error&.message.to_s
          state, = StateDelta.apply(state, {
                                      "add_failed" => [summary],
                                      "add_observations" => [{ "sequence" => sequence, "summary" => summary }],
                                      "add_attempted_digest" => candidate.argument_digest,
                                      "add_refused_digest" => refused_digest(candidate),
                                      "increment" => { "tool_actions" => 1 }
                                    })
          @ledger.checkpoint!(
            run: run, lease_token: lease_token, state: state,
            step: {
              sequence: sequence, status: "failed",
              observation_summary: summary,
              observation_digest: Digests.of(summary),
              recording_studio_ai_run_id: performance.run&.id
            },
            activities: [%w[step_completed]]
          )
          menu.consume(candidate.id)
          state, = StateDelta.apply(state, { "replace_candidate_index" => menu.index })
          return [state, menu]
        end

        summary, extra = refresh_observation(run, lease_token, state, candidate, performance.result)
        previous = state.digest_of_progress
        delta = ObservationReducer.fold(
          observation_delta(performance.result, sequence, summary, candidate.argument_digest),
          extra
        )
        state, compacted = StateDelta.apply(state, delta)
        streak = state.digest_of_progress == previous ? state.data["no_progress_streak"].to_i + 1 : 0
        state, = StateDelta.apply(state, { "set_no_progress_streak" => streak, "increment" => { "tool_actions" => 1 } })
        unless repeatable_tool?(candidate)
          state, = StateDelta.apply(state,
                                    { "add_refused_digest" => candidate.argument_digest })
        end
        state = remember_compaction(state, compacted)
        menu.consume(candidate.id)
        state, = StateDelta.apply(state, { "replace_candidate_index" => menu.index })
        state = shrink(request, run, lease_token, state)
        @ledger.checkpoint!(
          run: run, lease_token: lease_token, state: state,
          step: {
            sequence: sequence, status: "completed",
            observation_summary: summary,
            observation_digest: Digests.of(summary),
            progress_made: streak.zero?,
            controller_outcome: verdict&.probabilities,
            recording_studio_ai_run_id: performance.run&.id
          },
          activities: [%w[step_completed state_updated]]
        )
        if compacted
          @ledger.note_activity!(run: run, lease_token: lease_token, kind: "compacted",
                                 data: { "sequence" => sequence })
        end
        [state, menu]
      end

      def close_started_step(run, lease_token, state, step)
        state, = StateDelta.apply(state, {
                                    "add_attempted_digest" => step.argument_digest,
                                    "add_refused_digest" => (step.repeatable ? nil : step.argument_digest),
                                    "increment" => { "tool_actions" => 1 }
                                  })
        @ledger.checkpoint!(
          run: run, lease_token: lease_token, state: state,
          step: {
            sequence: step.sequence, status: "unresolved",
            observation_summary: "Interrupted before the tool finished."
          },
          activities: [%w[step_completed]]
        )
        [state, ActionMenu.new.restore_terminal(state.data["candidate_index"])]
      end

      def finish(_request, run, lease_token, state, candidate)
        response = Ai.synthesize(invocation: @invocation, run: run, lease_token: lease_token, state: state)
        return fail_synthesis(run, lease_token, response) if response.respond_to?(:error) && response.error

        if response.respond_to?(:run) && response.run
          @ledger.attach_ai_run!(run: run, lease_token: lease_token,
                                 ai_run: response.run)
        end
        text = response.try(:text).to_s
        digest = Digests.of("text" => text)
        summary = text.strip
        summary = "Answered." if summary.empty?
        @ledger.checkpoint!(
          run: run, lease_token: lease_token, state: state,
          step: step_attributes(
            run, "completed", "deliver", candidate&.id,
            observation_summary: summary, ai_run_id: response.try(:run)&.id
          ),
          activities: [%w[step_completed]]
        )
        @ledger.commit_succeeded!(run: run, lease_token: lease_token, digest: digest)
        Results::Completed.new(run: run.reload, output: Output.new(text: text, data: nil, citations: []))
      end

      def handoff(run, lease_token, candidate, verdict)
        target = Reference.new(key: candidate.handoff_key, version: candidate.handoff_version)
        @ledger.note_handoff!(agent_run_id: run.id, ai_run_id: nil, target: target, lease_token: lease_token)
        @ledger.checkpoint!(
          run: run, lease_token: lease_token, state: WorkingState.load(run.reload.working_state_json),
          step: step_attributes(
            run, "completed", "handoff", candidate.id,
            controller_outcome: verdict.probabilities.merge("reason" => verdict.reason)
          ).merge(record_json: { "reviewer" => "#{target.key} v#{target.version}" }),
          activities: []
        )
        @ledger.commit_handoff!(run: run, lease_token: lease_token, target: target)
        Results::HandoffRequested.new(run: run.reload, request: HandoffRequest.new(target: target))
      end

      def fail_synthesis(run, lease_token, response)
        error = response.error
        failure = Failure.new(
          category: error.respond_to?(:category) && error.category.present? ? error.category : "provider_error",
          code: "synthesis_failed",
          message: error.respond_to?(:message) ? error.message.to_s : "The answer could not be written.",
          retryable: error.respond_to?(:retryable?) ? error.retryable? : false
        )
        @ledger.commit_failed!(run: run, lease_token: lease_token, failure: failure)
        Results::Failed.new(run: run.reload, failure: failure)
      end

      def fail_run(run, lease_token, code, retryable)
        decision = code == "decision_failed"
        failure = Failure.new(
          category: decision ? "provider_error" : "budget",
          code: code,
          message: decision ? "Controller decision failed." : "Agent run stopped at #{code}.",
          retryable: retryable
        )
        @ledger.commit_failed!(run: run, lease_token: lease_token, failure: failure)
        Results::Failed.new(run: run.reload, failure: failure)
      end

      def remember_compaction(state, compacted)
        return state unless compacted

        updated, = StateDelta.apply(state, { "increment" => { "compactions" => 1 } })
        updated
      end

      def shrink(_request, run, lease_token, state)
        return state unless semantic_compact?(state)

        response = Ai.compact_state(
          invocation: @invocation, run: run, lease_token: lease_token, state: state,
          suffix: "compact-#{state.counter('compactions') + 1}"
        )
        data = response.try(:structured_data)
        data = { "increment" => { "compactions" => 1 } } unless data.is_a?(Hash)
        updated, = StateDelta.apply(state, data.merge("increment" => { "compactions" => 1 }))
        @ledger.note_activity!(run: run, lease_token: lease_token, kind: "compacted",
                               data: { "sequence" => run.agent_steps.maximum(:sequence).to_i })
        updated
      rescue *RecordingStudioAgents.lookup_errors, ContractError
        StateDelta.apply(state, { "increment" => { "compactions" => 1 } }).first
      end

      def semantic_compact?(state)
        return false if state.counter("compactions") >= 3
        return false if Array(state.data["recent_observations"]).empty?

        state.bytesize > soft_limit
      end

      def soft_limit
        soft = configuration.soft_working_state_bytes
        hard = configuration.maximum_working_state_bytes
        [soft, hard].min
      end

      def refresh_observation(run, lease_token, state, candidate, result)
        preview = ObservationReducer.preview(result)
        model = model_observation(run, lease_token, state, candidate, result, preview)
        summary = model["summary"].presence || preview.fetch("summary")
        [summary, model.fetch("delta")]
      end

      def model_observation(run, lease_token, state, candidate, result, preview)
        skipped = { "summary" => nil, "delta" => {} }
        return skipped unless preview["needs_model"]
        return skipped if state.counter("observation_calls") >= configuration.maximum_observation_calls

        response = Ai.observe(
          invocation: @invocation, run: run, lease_token: lease_token,
          prompt: observation_prompt(state, candidate, result),
          suffix: "observe-#{state.counter('observation_calls') + 1}"
        )
        accepted = ObservationReducer.accept(response.try(:structured_data), result)
        accepted["delta"] = accepted.fetch("delta").merge("increment" => { "observation_calls" => 1 })
        accepted
      rescue *RecordingStudioAgents.lookup_errors, ContractError
        { "summary" => nil, "delta" => { "increment" => { "observation_calls" => 1 } } }
      end

      def observation_prompt(state, candidate, result)
        tool = tool_definition(candidate)
        description = tool ? tool.description : candidate.purpose
        ContextBuilder.for_observation(
          state: state,
          tool_label: "#{candidate.tool_key} v#{candidate.tool_version}. #{description}",
          result: ObservationReducer.shareable(result)
        )
      end

      def stop_for_tool_error(run, lease_token, state, sequence, message)
        @ledger.checkpoint!(
          run: run, lease_token: lease_token, state: state,
          step: {
            sequence: sequence, status: "failed",
            observation_summary: message,
            observation_digest: Digests.of(message)
          },
          activities: [%w[step_completed]]
        )
        failure = Failure.new(category: "configuration", code: "tool_unavailable", message: message, retryable: false)
        @ledger.commit_failed!(run: run, lease_token: lease_token, failure: failure)
        Results::Failed.new(run: run.reload, failure: failure)
      end

      def observation_delta(result, sequence, summary, digest)
        findings = result.is_a?(Hash) ? Array(result["findings"] || result[:findings]) : []
        completed = result.is_a?(Hash) ? Array(result["completed"] || result[:completed]) : []
        {
          "add_findings" => findings,
          "add_completed" => completed,
          "add_observations" => [{ "sequence" => sequence, "summary" => summary }],
          "add_attempted_digest" => digest,
          "meet_criteria" => result.is_a?(Hash) ? Array(result["meet_criteria"] || result[:meet_criteria]) : []
        }
      end

      def candidate_from_step(step)
        ActionMenu::Candidate.new(
          id: step.candidate_id.to_s,
          type: "tool",
          purpose: step.observation_summary.to_s.presence || "Resume the tool",
          tool_key: step.tool_key,
          tool_version: step.tool_version,
          argument_digest: step.argument_digest,
          arguments: nil
        )
      end

      def refused_digest(candidate)
        return if repeatable_tool?(candidate)

        candidate.argument_digest
      end

      def tool_definition(candidate)
        RecordingStudioAI.tools.fetch(candidate.tool_key, version: candidate.tool_version)
      rescue *RecordingStudioAgents.lookup_errors
        nil
      end

      def repeatable_tool?(candidate)
        definition = tool_definition(candidate)
        return false unless definition

        definition.idempotent && !definition.destructive && !definition.requires_confirmation
      rescue *RecordingStudioAgents.lookup_errors
        false
      end
    end
  end
end
