# frozen_string_literal: true

module RecordingStudioAgents
  class Runtime
    module Decisions
      private

      def decide(_request, run, lease_token, state, menu, _steps)
        questions = Controller.questions(menu)
        return [Controller.verdict(:reason, nil, "no_candidates", {}), state] if questions.dig(:next_action,
                                                                                               :criteria).blank?

        response = ask_controller(run, lease_token, state, menu, questions)
        verdict = controller_verdict(response, state) do
          Controller.interpret(response.answers, menu: menu, state: state, configuration: configuration)
        end
        remember_decision(run, lease_token, state, response, verdict, menu)
      end

      def decide_if_answered(_request, run, lease_token, state)
        menu = ActionMenu.new
        response = ask_controller(run, lease_token, state, menu, Controller.completion_questions)
        verdict = controller_verdict(response, state) do
          Controller.interpret_completion(response.answers, configuration: configuration)
        end
        remember_decision(run, lease_token, state, response, verdict, menu)
      end

      def ask_controller(run, lease_token, state, menu, questions)
        Ai.decide(
          invocation: @invocation, run: run, lease_token: lease_token,
          state: ContextBuilder.for_decision(state: state, menu: menu, signals: signal_lines(state, run)),
          questions: questions,
          suffix: "decide-#{state.counter('controller_calls') + 1}"
        )
      end

      def controller_verdict(response, state)
        if response.respond_to?(:success?) && !response.success?
          return Controller.failure_verdict(
            response.error,
            configuration: configuration,
            reasoner_calls: state.counter("reasoner_calls")
          )
        end

        yield
      end

      def remember_decision(run, lease_token, state, response, verdict, menu)
        state, = StateDelta.apply(state, { "increment" => { "controller_calls" => 1 } })
        @ledger.checkpoint!(
          run: run, lease_token: lease_token, state: state,
          step: step_attributes(
            run, "completed", "decide", verdict.candidate_id,
            controller_outcome: verdict.probabilities.merge("reason" => verdict.reason, "name" => verdict.name.to_s),
            ai_run_id: response.try(:run)&.id,
            progress_made: verdict.probabilities["progress_made"].to_f >= configuration.progress_probability
          ).merge(record_json: decision_record(verdict, menu)),
          activities: [%w[controller_evaluated]]
        )
        if response.respond_to?(:run) && response.run
          @ledger.attach_ai_run!(run: run, lease_token: lease_token,
                                 ai_run: response.run)
        end
        [verdict, state]
      end
    end
  end
end
