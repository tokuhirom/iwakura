require 'minitest/unit'
require 'minitest/autorun'
require './iwakura'

class TestSimple < MiniTest::Unit::TestCase
  def test_simple
    tmpl = Iwakura.new()
    assert_equal tmpl.render_string('helloHello: [% 3+2 %]'), "helloHello: 5"
    assert_equal tmpl.render_string('helloHello: [% 3-2 %]'), "helloHello: 1"
    assert_equal tmpl.render_string('helloHello: [% 3-2-4 %]'), "helloHello: #{3-2-4}"
    # (- (- 3 2) 4)
  end
end
