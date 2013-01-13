require 'minitest/unit'
require 'minitest/autorun'
require './iwakura'

class TestSimple < MiniTest::Unit::TestCase
  def setup
    @tmpl = Iwakura.new()
  end

  def test_for
    assert_equal @tmpl.render_string('[% for i in [1,2,3] %]p[% i %][% end %]'), "p1p2p3"
    assert_equal @tmpl.render_string('[% for i in [1,2,3] %]i[% i %][% for j in [4,5,6] %]j[% j %][% end %][% end %]'), "i1j4j5j6i2j4j5j6i3j4j5j6"
    assert_equal @tmpl.render_string('[% for i in [1,2,3] %]i[% i %][% for j in [4,5,6] %]j[% i*j %][% end %][% end %]'), "i1j4j5j6i2j8j10j12i3j12j15j18"
    assert_equal @tmpl.render_string('W[% for i in [] %]p[% i %][% end %]X'), "WX"
  end

  def test_if
    assert_equal @tmpl.render_string('helloHello:[% if nil %]e[% end %]'), "helloHello:"
    assert_equal @tmpl.render_string('helloHello:[% if nil %]e[% end %]P'), "helloHello:P"
    assert_equal @tmpl.render_string('helloHello:[% if 1 %]e[% end %]'), "helloHello:e"
    assert_equal @tmpl.render_string('helloHello:[% if 1 %]e[% end %]E'), "helloHello:eE"
    assert_equal @tmpl.render_string('helloHello:[% if 1 %]e[% if 3 %]o[% end %]f[% end %]E'), "helloHello:eofE"
    assert_equal @tmpl.render_string('helloHello:[% if 1 %]e[% if nil %]o[% end %]f[% end %]E'), "helloHello:efE"
    assert_equal @tmpl.render_string('helloHello:[% if nil %]e[% if 1 %]o[% end %]f[% end %]E'), "helloHello:E"
  end

  def test_simple
    assert_equal @tmpl.render_string('helloHello: [% 4 %]'), "helloHello: #{4}"
    assert_equal @tmpl.render_string('helloHello: [% 3+2 %]'), "helloHello: 5"
    assert_equal @tmpl.render_string('helloHello: [% 3-2 %]'), "helloHello: 1"
    assert_equal @tmpl.render_string('helloHello: [% 3-2-4 %]'), "helloHello: #{3-2-4}"
    assert_equal @tmpl.render_string('helloHello: [% 3*4*8 %]'), "helloHello: #{3*4*8}"
    # @tmpl.enable_disasm = true
    assert_equal @tmpl.render_string('helloHello: [% 8/2/2 %]'), "helloHello: #{8/2/2}"
    assert_equal @tmpl.render_string('helloHello: [% 8/2/2 %]'), "helloHello: #{8/2/2}"
    assert_equal @tmpl.render_string('helloHello: [% nil %]'), "helloHello: #{nil}"
  end

  def test_array
    assert_equal @tmpl.render_string('[% [1,2,3] %]'), "[1, 2, 3]"
    assert_equal @tmpl.render_string('[% [] %]'), "[]"
    assert_equal @tmpl.render_string('[% [1,] %]'), "[1]"
  end
end
