# frozen_string_literal: true

module RecordingStudioAgents
  module Admin
    # Widget comparisons use the same 27-day window Admin::Period uses for
    # last_4_weeks. Admin owns the preset. This gem does not prepend Period.
    module LastFourWeeks
      LOOKBACK_DAYS = 27

      module_function

      def current_range(now: Time.current)
        start_date = now.to_date - LOOKBACK_DAYS
        start_date.beginning_of_day..now
      end

      def previous_range(now: Time.current)
        current_start = now.to_date - LOOKBACK_DAYS
        span_days = LOOKBACK_DAYS + 1
        previous_start = current_start - span_days
        previous_end = current_start - 1
        previous_start.beginning_of_day..previous_end.end_of_day
      end
    end
  end
end
