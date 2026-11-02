# frozen_string_literal: true

# Offline stand-in for Gemini generation and TypeSafe decisions.
# Registered with RecordingStudioAI.register_provider when no provider key is set.
class DummyStudioProvider < RecordingStudioAI::Providers::Base
  def configured?
    true
  end

  def generate(request:, candidate:)
    _model = candidate.model
    RecordingStudioAI::Providers::Result.new(text: text_for(request))
  end

  def decide(request:, candidate:)
    _model = candidate.model
    questions = request.fetch(:questions)
    RecordingStudioAI::Providers::DecisionResult.new(
      answers: answers_for(questions, request.fetch(:state).to_s)
    )
  end

  private

  def text_for(request)
    schema = request[:schema]
    return answer_text(request) if schema.nil?

    JSON.generate(structured_for(schema, request))
  end

  def answer_text(request)
    return "The public web has an answer." if request[:purpose].to_s.include?("web_researcher")

    "Found Getting Started."
  end

  def structured_for(schema, request)
    required = Array(schema["required"] || schema[:required]).map(&:to_s)
    return plan_for(request) if required.include?("plan")
    return next_actions_for(request) if required.include?("action_candidates")
    return observe_for(request) if required.include?("summary")

    arguments_for(request)
  end

  def plan_for(request)
    if web?(request)
      return {
        "plan" => [ "Search the public web", "Answer" ],
        "success_criteria" => [ { "id" => "answered", "text" => "The question has an answer with sources" } ],
        "current_objective" => "Answer from the public web",
        "action_candidates" => tool_candidates(request) + [ deliver("Answer the question") ]
      }
    end

    if support?(request) && !allows?(request, "find_page") && !allows?(request, "list_pages")
      return {
        "plan" => [ "Answer" ],
        "success_criteria" => [ { "id" => "answered", "text" => "The ticket has an answer" } ],
        "current_objective" => "Answer the ticket",
        "action_candidates" => [ deliver("Answer the ticket") ]
      }
    end

    {
      "plan" => [ "List the pages", "Find the named page", "Answer" ],
      "success_criteria" => [ { "id" => "found", "text" => "The named page was found" } ],
      "current_objective" => "Find the named page",
      "action_candidates" => tool_candidates(request) + [ deliver("Answer with the page") ]
    }
  end

  def next_actions_for(request)
    { "action_candidates" => tool_candidates(request) + [ deliver("Answer") ] }
  end

  def observe_for(request)
    text = "#{request[:prompt]} #{request[:system_instruction]}"
    summary = if text.include?("web_search")
                "Searched the web."
              elsif text.include?("list_pages")
                "Listed the pages."
              else
                "Found the page."
              end
    { "summary" => summary }
  end

  def arguments_for(request)
    text = "#{request[:prompt]} #{request[:system_instruction]}"
    return { "query" => "public web" } if text.include?("web_search") || text.include?("query")

    { "title" => "Getting Started" }
  end

  def tool_candidates(request)
    candidates = []
    if allows?(request, "list_pages")
      candidates << tool("list", "list_pages", "List the pages in this workspace", {})
    end
    if allows?(request, "find_page")
      candidates << tool("find", "find_page", "Find the named page", { "title" => "Getting Started" })
    end
    if allows?(request, "web_search") || web?(request)
      candidates << tool("search", "web_search", "Search the public web", { "query" => "public web" })
    end
    candidates
  end

  def allows?(request, key)
    "#{request[:prompt]}\n#{request[:system_instruction]}".include?(key)
  end

  def web?(request)
    request[:purpose].to_s.include?("web_researcher")
  end

  def support?(request)
    request[:purpose].to_s.include?("support_clerk")
  end

  def tool(id, key, purpose, arguments)
    {
      "id" => id,
      "type" => "tool",
      "purpose" => purpose,
      "tool_key" => key,
      "tool_version" => 1,
      "arguments" => arguments
    }
  end

  def deliver(purpose)
    { "id" => "deliver", "type" => "deliver", "purpose" => purpose }
  end

  def answers_for(questions, state)
    chosen = choice_id(questions)
    answers = {}
    questions.each do |entry|
      canonical = entry.key.canonical_key
      answers[canonical] = answer_for(entry, chosen, state)
    end
    RecordingStudioAI::Decisions::AnswerSet.from_canonical(question_set: questions, answers: answers)
  end

  def answer_for(entry, chosen, state)
    case entry.question.type
    when :choice
      probabilities = entry.question.criteria.to_h do |criterion|
        id = criterion.key.canonical_key
        [ id, id == chosen ? 0.9 : 0.05 ]
      end
      RecordingStudioAI::Decisions::ChoiceAnswer.new(
        choice: chosen,
        probabilities: probabilities,
        confidence: 0.9
      )
    when :noul
      RecordingStudioAI::Decisions::NoulAnswer.new(probability: noul_probability(entry.key.canonical_key, chosen, state))
    else
      raise RecordingStudioAI::Providers::UnsupportedOperationError.new(
        operation: :decision,
        provider: :dummy_studio
      )
    end
  end

  def choice_id(questions)
    choice = questions.find { |entry| entry.question.type == :choice }
    return "deliver" unless choice

    ids = choice.question.criteria.map { |criterion| criterion.key.canonical_key }
    %w[list search find].find { |id| ids.include?(id) } || ids.first
  end

  def noul_probability(key, chosen, state)
    case key
    when "finished"
      chosen == "deliver" || state.include?("Found the page") || state.include?("Searched the web") ? 0.95 : 0.1
    when "stuck", "needs_reasoning"
      0.05
    else
      0.8
    end
  end
end
