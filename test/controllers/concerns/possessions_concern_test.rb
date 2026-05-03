# frozen_string_literal: true

require 'test_helper'

class PossessionsConcernTest < ActiveSupport::TestCase
  class Harness
    include Possessions
    include Rails.application.routes.url_helpers

    def default_url_options
      { host: 'www.example.com', protocol: 'https' }
    end
  end

  setup do
    @harness = Harness.new
  end

  test 'get_possessions_for_user returns an ordered possession scope' do
    user = users(:one)
    rel = @harness.get_possessions_for_user(possessions: user.possessions)

    assert_kind_of ActiveRecord::Relation, rel
    assert_predicate rel, :any?
    assert_nothing_raised { rel.load }
  end

  test 'get_grouped_sub_categories groups presenters like dashboard possessions navigation' do
    user = users(:one)
    presenters = PossessionPresenterService.map_to_presenters(
      @harness.get_possessions_for_user(possessions: user.possessions)
    )

    grouped = @harness.get_grouped_sub_categories(possessions: presenters)

    assert grouped.is_a?(Array)

    grouped.each do |category, subs|
      assert_instance_of Category, category
      subs.each { |row| assert_match %r{\A/dashboard/products}, row[:path] }
    end
  end
end
