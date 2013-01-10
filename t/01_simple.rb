require 'minitest/unit'
require 'minitest/autorun'
require './iwakura'

class TestSimple < MiniTest::Unit::TestCase
  def test_simple
    tmpl = Iwakura.new()
    assert_equal tmpl.render('t/tmpl/foo.tt', {}), "helloHello: 5\n"
  end
end
