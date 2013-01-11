require 'minitest/unit'
require 'minitest/autorun'
require './iwakura'

class TestSimple < MiniTest::Unit::TestCase
  def test_simple
    tmpl = Iwakura.new()
    assert_equal tmpl.render_string('helloHello: [% 4 %]'), "helloHello: #{4}"
    assert_equal tmpl.render_string('helloHello: [% 3+2 %]'), "helloHello: 5"
    assert_equal tmpl.render_string('helloHello: [% 3-2 %]'), "helloHello: 1"
    assert_equal tmpl.render_string('helloHello: [% 3-2-4 %]'), "helloHello: #{3-2-4}"
    assert_equal tmpl.render_string('helloHello: [% 3*4*8 %]'), "helloHello: #{3*4*8}"
    # tmpl.enable_disasm = true
    assert_equal tmpl.render_string('helloHello: [% 8/2/2 %]'), "helloHello: #{8/2/2}"
    assert_equal tmpl.render_string('helloHello: [% 8/2/2 %]'), "helloHello: #{8/2/2}"
    assert_equal tmpl.render_string('helloHello: [% nil %]'), "helloHello: #{nil}"

    assert_equal tmpl.render_string('helloHello:[% IF nil %]e[% END %]'), "helloHello:"
    assert_equal tmpl.render_string('helloHello:[% IF nil %]e[% END %]P'), "helloHello:P"
    assert_equal tmpl.render_string('helloHello:[% IF 1 %]e[% END %]'), "helloHello:e"
    assert_equal tmpl.render_string('helloHello:[% IF 1 %]e[% END %]E'), "helloHello:eE"
    assert_equal tmpl.render_string('helloHello:[% IF 1 %]e[% IF 3 %]o[% END %]f[% END %]E'), "helloHello:eofE"
    assert_equal tmpl.render_string('helloHello:[% IF 1 %]e[% IF nil %]o[% END %]f[% END %]E'), "helloHello:efE"
    assert_equal tmpl.render_string('helloHello:[% IF nil %]e[% IF 1 %]o[% END %]f[% END %]E'), "helloHello:E"
  end
end
