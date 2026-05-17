# frozen_string_literal: true

require 'test_helper'

class SlugRouteConstraintsTest < ActiveSupport::TestCase
  test 'slug patterns match route constraint and parameterize-style slugs' do
    assert_match SlugRouteConstraints::SLUG_PATH_CONSTRAINT, 'my-event-2'
    assert_match SlugRouteConstraints::SLUG_ROUTE_PATTERN, 'my-event-2'
    assert_not 'my_event'.match?(SlugRouteConstraints::SLUG_ROUTE_PATTERN)
    assert_not 'My Event'.match?(SlugRouteConstraints::SLUG_ROUTE_PATTERN)
  end

  test 'included models expose slug constants' do
    [Event, Setup, CustomProduct].each do |model|
      assert_equal SlugRouteConstraints::SLUG_PATH_CONSTRAINT, model::SLUG_PATH_CONSTRAINT
      assert_equal SlugRouteConstraints::SLUG_ROUTE_PATTERN, model::SLUG_ROUTE_PATTERN
    end
  end
end
