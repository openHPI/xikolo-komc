# frozen_string_literal: true

require 'spec_helper'

class SimpleController
  class << self
    def helper_method(*); end

    def before_action(*); end
  end

  def initialize(controller_name, params)
    @controller_name = controller_name
    @params = params
  end

  attr_reader :controller_name, :params

  def url_options
    # "host" is needed for generation of absolute URLs.
    # "_recall" holds the key-value pairs that are automatically injected into generated URLs if
    # omitted when calling route helpers.
    {host: 'example.org', _recall: @params}
  end

  include Rails.application.routes.url_helpers
end

describe PinboardRoutesHelper, type: :helper do
  subject(:controller_with_helper) do
    controller_included.new(controller_name, params)
  end

  let(:controller_included) { SimpleController.send :include, described_class }
  let(:params) { {} }
  let(:controller_name) { 'a controller' }

  describe 'redirecting routes' do
    context 'course' do
      let(:params) { {course_id: 7} }

      it 'routes question_url correctly' do
        route = controller_with_helper.question_url(id: 2)
        expect(route).to eq 'http://example.org/courses/7/question/2'
      end

      it 'routes question_path correctly' do
        route = controller_with_helper.question_path(id: 2)
        expect(route).to eq '/courses/7/question/2'
      end

      it 'routes question_index_url correctly' do
        route = controller_with_helper.question_index_url
        expect(route).to eq 'http://example.org/courses/7/question'
      end

      it 'routes question_index_path correctly' do
        route = controller_with_helper.question_index_path
        expect(route).to eq '/courses/7/question'
      end

      it 'routes pinboard_index_url correctly' do
        route = controller_with_helper.pinboard_index_url
        expect(route).to eq 'http://example.org/courses/7/pinboard'
      end

      it 'routes pinboard_index_path correctly' do
        route = controller_with_helper.pinboard_index_path
        expect(route).to eq '/courses/7/pinboard'
      end
    end

    context 'learning_room' do
      let(:params) { {course_id: 7, learning_room_id: 22} }

      it 'routes question_url correctly' do
        route = controller_with_helper.question_url(id: 2)
        expect(route).to eq 'http://example.org/courses/7/learning_rooms/22/question/2'
      end

      it 'routes question_path correctly' do
        route = controller_with_helper.question_path(id: 2)
        expect(route).to eq '/courses/7/learning_rooms/22/question/2'
      end

      it 'routes question_index_url correctly' do
        route = controller_with_helper.question_index_url
        expect(route).to eq 'http://example.org/courses/7/learning_rooms/22/question'
      end

      it 'routes question_index_path correctly' do
        route = controller_with_helper.question_index_path
        expect(route).to eq '/courses/7/learning_rooms/22/question'
      end

      it 'routes pinboard_index_url correctly' do
        route = controller_with_helper.pinboard_index_url
        expect(route).to eq 'http://example.org/courses/7/learning_rooms/22/pinboard'
      end

      it 'routes pinboard_index_path correctly' do
        route = controller_with_helper.pinboard_index_path
        expect(route).to eq '/courses/7/learning_rooms/22/pinboard'
      end
    end
  end

  describe '#in_learning_room_context?' do
    context 'in a resource under a learning room' do
      let(:params) { {learning_room_id: 'something', id: 'another thing'} }

      it { is_expected.to be_in_learning_room_context }
    end

    context 'not in a learning room context (for instance course)' do
      let(:params) { {id: 'lalala'} }
      let(:controller_name) { 'courses' }

      it { is_expected.not_to be_in_learning_room_context }
    end

    # NOTE: the common module defines an in_learning_room_context? method that returns true
  end
end
