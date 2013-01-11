require 'minitest/unit'
require 'minitest/autorun'
require './iwakura'

class TestSimple < MiniTest::Unit::TestCase
  def test_simple
    tmpl = Iwakura.new()
    assert_equal tmpl.render_string('helloHello: [% 3+2 %]'), "helloHello: 5"
    assert_equal tmpl.render_string('helloHello: [% 3-2 %]'), "helloHello: 1"
    assert_equal tmpl.render_string('helloHello: [% 3-2-4 %]'), "helloHello: #{3-2-4}"
    assert_equal tmpl.render_string('helloHello: [% 3*4*8 %]'), "helloHello: #{3*4*8}"
    # tmpl.enable_disasm = true
    assert_equal tmpl.render_string('helloHello: [% 8/2/2 %]'), "helloHello: #{8/2/2}"
  end
end
