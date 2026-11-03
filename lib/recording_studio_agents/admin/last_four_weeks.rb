# frozen_string_literal: true

module RecordingStudioAgents
  module Admin
    # Widget comparisons use Admin's last_4_weeks window. Admin owns the preset.
    # This gem does not prepend Period.
    module LastFourWeeks
      # Same number Admin uses for last_4_weeks. Prefer lookback_days in new code.
      LOOKBACK_DAYS = RecordingStudioAdmin::Period::LAST_4_WEEKS_LOOKBACK_DAYS

      module_function

      def lookback_days
        LOOKBACK_DAYS
      end

      def current_range(now: Time.current)
        start_date = now.to_date - lookback_days
        start_date.beginning_of_day..now
      end

      def previous_range(now: Time.current)
        current_start = now.to_date - lookback_days
        span_days = lookback_days + 1
        previous_start = current_start - span_days
        previous_end = current_start - 1
        previous_start.beginning_of_day..previous_end.end_of_day
      end
    end

    # Old name for LastFourWeeks. Not prepended onto Admin Period.
    LastFourWeeksPeriod = LastFourWeeks
  end
end
