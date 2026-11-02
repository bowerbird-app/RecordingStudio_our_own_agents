# frozen_string_literal: true

# Demo runs script tool results so the playground can finish without a live model.
# Direct executor calls in tests leave the flag unset and run the real tool.
module DummyOfflineTools
  THREAD_KEY = :dummy_offline_scripted_tools

  module_function

  def scripted
    Thread.current[THREAD_KEY] = true
    yield
  ensure
    Thread.current[THREAD_KEY] = nil
  end

  def scripted?
    Thread.current[THREAD_KEY] == true
  end

  def install!
    wrap_web_search
  end

  def wrap_web_search
    return unless defined?(RecordingStudio::WebSearch::AiTool)

    definition = RecordingStudio::WebSearch::AiTool::DEFINITION
    current = RecordingStudioAI.tools.fetch(definition.fetch(:key), version: definition.fetch(:version))
    return if current&.executor_label.to_s.start_with?("DummyOffline(")

    original = definition.fetch(:executor)
    RecordingStudioAI.tools.register(
      **definition,
      override: true,
      executor_label: "DummyOffline(#{definition.fetch(:executor_label)})",
      executor: lambda do |arguments, context|
        next scripted_result("web_search") if DummyOfflineTools.scripted?

        original.call(arguments, context)
      end
    )
  end

  def scripted_result(tool_key)
    case tool_key.to_s
    when "list_pages"
      { "summary" => "Listed the pages.", "findings" => [ "Listed the pages." ] }
    when "web_search"
      {
        "summary" => "Searched the web.",
        "findings" => [ "Searched the web." ],
        "meet_criteria" => [ "answered" ]
      }
    when "find_page"
      {
        "summary" => "Found the page.",
        "findings" => [ "Found the page." ],
        "meet_criteria" => [ "found" ]
      }
    else
      { "summary" => "Finished.", "findings" => [ "Finished." ] }
    end
  end
end
