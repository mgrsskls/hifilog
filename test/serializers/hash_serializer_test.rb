# frozen_string_literal: true

require 'test_helper'

class HashSerializerTest < ActiveSupport::TestCase
  test 'dump serializes hashes to json strings for storage' do
    payload = { 'foo' => 1, bar: 'two' }

    assert_equal({ 'foo' => 1, 'bar' => 'two' }, JSON.parse(HashSerializer.dump(payload)))
  end

  test 'load normalizes blanks and wraps entries with indifferent access' do
    assert_empty HashSerializer.load(nil)

    loaded = HashSerializer.load({ foo: :two })
    assert_equal :two, loaded[:foo]
    assert_equal :two, loaded['foo']
  end
end
