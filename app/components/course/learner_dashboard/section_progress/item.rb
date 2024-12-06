# frozen_string_literal: true

module Course
  module LearnerDashboard
    module SectionProgress
      class Item < ApplicationComponent
        include UUIDHelper
        include ProgressHelper

        EXERCISE_TYPES =
          {
            'bonus' => 'lightbulb-on+circle-star',
            'selftest' => 'lightbulb-on',
            'main' => 'money-check-pen',
            'survey' => 'clipboard-list-check',
          }.freeze

        CONTENT_TYPES =
          {
            'video' => 'video',
            'rich_text' => 'file-lines',
            'lti_exercise' => 'display-code',
          }.freeze

        def initialize(item, course)
          @item = item
          @course = course
        end

        def title
          @item['title']
        end

        def css_classes
          [].tap do |cls|
            cls << "section-material__item--#{state}" if state.present?
            cls << 'section-material__item--optional' if optional?
          end
        end

        def percentage_variable
          {
            completed: '--percentage: 100%',
            critical: '--percentage: 15%',
            warning: "--percentage: #{percentage}%",
          }.fetch(state, nil)
        end

        def path
          Rails.application.routes.url_helpers.course_item_path(@course.course_code, short_uuid(@item['id']))
        end

        def icon
          case @item['content_type']
            when 'quiz'
              EXERCISE_TYPES.fetch(@item['exercise_type'])
            else
              CONTENT_TYPES.fetch(@item['content_type'], 'money-check-pen')
          end
        end

        private

        def percentage
          @percentage ||= calc_progress(@item['user_points'], @item['max_points'])
        end

        def state
          @state ||= begin
            item = case @item['content_type']
                     when 'quiz'
                       survey? ? Survey.new(@item) : Gradable.new(@item, percentage)
                     when 'lti_exercise'
                       Gradable.new(@item, percentage)
                     else
                       Other.new(@item)
                   end

            if item.completed?
              :completed
            elsif item.warning?
              :warning
            elsif item.critical?
              :critical
            end
          end
        end

        def optional?
          @item['optional'] == true
        end

        def survey?
          @item['exercise_type'] == 'survey'
        end
      end

      class Gradable
        def initialize(item, percentage)
          @item = item
          @percentage = percentage
        end

        def completed?
          return false unless graded_or_submitted?

          @item['max_points'].zero? || @percentage > 95
        end

        def warning?
          return false unless graded_or_submitted?

          @percentage >= 50 && @percentage <= 95
        end

        def critical?
          return false unless graded_or_submitted? || visited?

          (@item['max_points'].zero? && visited?) ||
            @percentage < 50
        end

        private

        def graded_or_submitted?
          %w[graded submitted].include? @item['user_state']
        end

        def visited?
          @item['user_state'] == 'visited'
        end
      end

      class Survey
        def initialize(item)
          @item = item
        end

        def completed?
          %w[graded submitted].include? @item['user_state']
        end

        def warning?; end

        def critical?; end
      end

      class Other
        def initialize(item)
          @item = item
        end

        def completed?
          @item['user_state'] == 'visited'
        end

        def warning?; end

        def critical?; end
      end
    end
  end
end