# frozen_string_literal: true

# Public demo hook for the librarian create action and its provider test.
# The controller does not expose this as an action.
module AgentsGenerateStub
  def self.with_generate_stub
    return yield if generative_provider_configured?

    DummyGenerateStub.with_hook(method(:stubbed_response)) { yield }
  end

  def self.generative_provider_configured?
    configuration = RecordingStudioAI.configuration
    configuration.gemini_api_key.present? || configuration.openai_api_key.present?
  end

  def self.stubbed_response(**kwargs)
    ai_run = persist_stubbed_ai_run(**kwargs)
    RecordingStudioAI::Contracts::GenerationResponse.new(
      operation: "generation",
      purpose: kwargs[:purpose] || "agent_page_librarian",
      text: "Found Getting Started.",
      run: ai_run
    )
  end

  def self.persist_stubbed_ai_run(**kwargs)
    initiator = kwargs.fetch(:initiator)
    root = kwargs.fetch(:root_recording)
    now = Time.current
    context = kwargs[:context_recording]

    ai_run = RecordingStudioAI::Run.create!(
      operation: "generation",
      purpose: kwargs[:purpose],
      status: "completed",
      root_recording_id: root.id,
      context_recording_id: context&.id,
      initiator_type: initiator.class.name,
      initiator_id: initiator.id.to_s,
      initiator_kind: (kwargs[:initiator_kind] || :user).to_s,
      execution_source: (kwargs[:execution_source] || :web).to_s,
      request_id: kwargs[:request_id],
      metadata: kwargs[:metadata],
      started_at: now,
      completed_at: now,
      custom_tool_invocation_count: 1,
      total_tokens: 1_200,
      latency_ms: 400,
      input_tokens: 900,
      output_tokens: 300
    )
    RecordingStudioAI::CustomToolInvocation.create!(
      run: ai_run,
      tool_key: "find_page",
      tool_version: 1,
      tool_name_snapshot: "Find page",
      status: "completed",
      read_only: true,
      destructive: false,
      requires_confirmation: false,
      idempotent: true,
      confirmation_status: "not_required",
      started_at: now,
      completed_at: now
    )
    ai_run
  end
end
