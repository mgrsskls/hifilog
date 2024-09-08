require 'test_helper'

class AppNewsTest < ActiveSupport::TestCase
  test 'formatted_text' do
    assert_equal '<ul>
<li>list item 1</li>
<li>list item 2</li>
</ul>', app_news(:one).formatted_text.strip
  end
end
