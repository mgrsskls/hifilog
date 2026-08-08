# frozen_string_literal: true

require 'test_helper'

class RelevanceOrderingTest < ActiveSupport::TestCase
  include RelevanceOrdering

  test 'orders exact above prefix above contains above fuzzy, ignoring punctuation on both sides' do
    tier_sql = send(:relevance_tier_sql, 'T.L.A.', exact: ['t.name'], contains: ['t.name'])

    rows = ActiveRecord::Base.connection.select_all(<<~SQL.squish).rows
      SELECT t.name
      FROM (VALUES ('TLA'), ('TLA Extended'), ('Something Contains TLA Too'), ('Totally Unrelated')) AS t(name)
      ORDER BY #{tier_sql}
    SQL

    assert_equal ['TLA', 'TLA Extended', 'Something Contains TLA Too', 'Totally Unrelated'], rows.flatten
  end

  test 'closeness breaks ties within a tier by trigram similarity' do
    tier_sql = send(:relevance_tier_sql, 'atrium open', exact: ['t.name'], contains: ['t.name'])

    rows = ActiveRecord::Base.connection.select_all(<<~SQL.squish).rows
      SELECT t.name
      FROM (VALUES ('Atrim Opne'), ('Completely Unrelated Text')) AS t(name)
      ORDER BY #{tier_sql}
    SQL

    assert_equal 'Atrim Opne', rows.first.first
  end

  test 'returns nil when the query has no alphanumeric characters left after stripping' do
    assert_nil send(:relevance_tier_sql, '!!!', exact: ['t.name'], contains: ['t.name'])
  end
end
