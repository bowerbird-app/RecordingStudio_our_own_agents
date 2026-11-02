# frozen_string_literal: true

module RecordingStudioAgents
  class Error < StandardError
  end

  class ConfigurationError < Error
  end

  class ContractError < Error
  end

  class AgentDisabled < Error
    attr_reader :key, :version

    def initialize(key, version)
      @key = key.to_s
      @version = version
      super("Agent #{key} version #{version} is disabled")
    end
  end

  class IdempotencyConflict < Error
  end

  class InvalidTransition < Error
  end

  # Failures from a missing table, a down database, or an AI contract/execution
  # error. Call sites rescue this list and return a fallback. NoMethodError is
  # not included.
  def self.lookup_errors
    @lookup_errors ||= [
      ActiveRecord::RecordNotFound,
      ActiveRecord::StatementInvalid,
      ActiveRecord::ConnectionNotEstablished,
      ActiveRecord::ConnectionFailed,
      RecordingStudioAI::Errors::ContractValidationError,
      RecordingStudioAI::Errors::ResolutionError,
      RecordingStudioAI::Errors::ExecutionError
    ].freeze
  end

  class ExecutionFailed < Error
    attr_reader :result

    def initialize(result)
      @result = result
      message = result.respond_to?(:failure) ? result.failure.message : result.to_s
      super(message)
    end
  end
end
