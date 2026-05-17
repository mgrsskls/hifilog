# frozen_string_literal: true

require 'test_helper'

class SafeRedirectResolveTest < ActiveSupport::TestCase
  HOST = 'www.example.com'
  PORT = 443

  test 'allows relative paths' do
    assert_equal '/dashboard', SafeRedirect.resolve('/dashboard', host: HOST, port: PORT)
    assert_equal '/brands?sort=name', SafeRedirect.resolve('/brands?sort=name', host: HOST, port: PORT)
  end

  test 'allows same-host absolute URLs' do
    assert_equal '/brands', SafeRedirect.resolve("https://#{HOST}/brands", host: HOST, port: PORT)
  end

  test 'rejects external hosts' do
    assert_nil SafeRedirect.resolve('https://evil.com/phish', host: HOST, port: PORT)
  end

  test 'rejects protocol-relative URLs' do
    assert_nil SafeRedirect.resolve('//evil.com/phish', host: HOST, port: PORT)
  end

  test 'rejects dangerous schemes' do
    assert_nil SafeRedirect.resolve('javascript:alert(1)', host: HOST, port: PORT)
    assert_nil SafeRedirect.resolve('data:text/html,hi', host: HOST, port: PORT)
  end

  test 'rejects paths without leading slash' do
    assert_nil SafeRedirect.resolve('dashboard', host: HOST, port: PORT)
  end

  test 'rejects backslash paths' do
    assert_nil SafeRedirect.resolve('/\\evil.com', host: HOST, port: PORT)
    assert_nil SafeRedirect.resolve('/%5Cevil.com', host: HOST, port: PORT)
  end

  test 'rejects encoded protocol-relative paths' do
    assert_nil SafeRedirect.resolve('/%2f%2fevil.com', host: HOST, port: PORT)
  end

  test 'rejects path traversal segments' do
    assert_nil SafeRedirect.resolve('/dashboard/../admin', host: HOST, port: PORT)
  end

  test 'rejects mismatched port on absolute URLs' do
    assert_nil SafeRedirect.resolve("http://#{HOST}:3000/brands", host: HOST, port: PORT)
  end
end
