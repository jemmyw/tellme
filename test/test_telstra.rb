# Code Generated by ZenTest v. 3.11.0
#                 classname: asrt / meth =  ratio%
#              TelstraUsage:    0 /    2 =   0.00%

require 'test/unit' unless defined? $ZENTEST and $ZENTEST
require 'mocha'
require 'lib/tellme/telstra'

class TestTelstraUsage < Test::Unit::TestCase
  def setup
    @telstra = TelstraUsage.new('11111', 'xxx')

    response = {'content-type' => 'text/html'}
    page = WWW::Mechanize::Page.new(
      nil, response, File.read('test/usagemeter.html'), 200, nil
    )
    page2 = WWW::Mechanize::Page.new(
      nil, response, File.read('test/meter2.html'), 200, nil
    )

    WWW::Mechanize.any_instance.stubs(:get).with("https://www.telstraclear.co.nz/usagemeter/").returns(page)
    WWW::Mechanize.any_instance.stubs(:submit).returns(page2)
    @telstra.fetch
  end

  def test_percent
    assert_equal 56, @telstra.percent
  end

  def test_end_date
    assert_equal Time.local(2008, 11, 26, 12, 0, 0, 0), @telstra.end_date
  end

  def test_left
    assert_equal 17.57, @telstra.left
  end

  def test_percent_of_date
    assert_equal 32, @telstra.percent_of_date
  end

  def test_start_date
    assert_equal Time.local(2008, 10, 27, 12, 0, 0, 0), @telstra.start_date
  end

  def test_used
    assert_equal 22.43, @telstra.used
  end
end