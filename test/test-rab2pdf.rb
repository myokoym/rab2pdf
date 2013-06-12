#!/usr/bin/env ruby

require "test-unit"
require "test/unit/notify"
require "test/unit/rr"
require "rack/test"

class Rab2pdfTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    @app ||= Rack::Builder.parse_file("config.ru").first
  end

  def test_index
    get "/"
    assert_true(last_response.ok?)
  end
end
