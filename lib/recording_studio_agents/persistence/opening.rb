# frozen_string_literal: true

module RecordingStudioAgents
  module Persistence
    class Opening
      attr_reader :kind, :task, :run, :lease_token

      def initialize(kind:, task:, run:, lease_token: nil)
        @kind = kind
        @task = task
        @run = run
        @lease_token = lease_token
      end

      def acquired?
        kind == :acquired
      end

      def existing?
        kind == :existing
      end

      def in_progress?
        kind == :in_progress
      end

      def blocked?
        kind == :blocked
      end
    end
  end
end
