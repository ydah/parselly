# frozen_string_literal: true

require 'test/unit'
require 'parselly'

class TestParselly < Test::Unit::TestCase
  def test_special_case_single_dash
    assert_equal '\\-', Parselly.sanitize('-')
  end

  def test_null_character
    assert_equal "\uFFFD", Parselly.sanitize("\0")
  end

  def test_control_characters
    input = "\x01\x02\x7F"
    expected = "\\1 \\2 \\7f "
    assert_equal expected, Parselly.sanitize(input)
  end

  def test_first_character_digit
    input = '1abc'
    expected = "\\31 abc"
    assert_equal expected, Parselly.sanitize(input)
  end

  def test_second_character_digit_after_dash
    input = '-1abc'
    expected = "-\\31 abc"
    assert_equal expected, Parselly.sanitize(input)
  end

  def test_alphanumeric_and_safe_characters
    input = 'a-Z_0-9'
    assert_equal 'a-Z_0-9', Parselly.sanitize(input)
  end

  def test_escape_special_characters
    input = '!@#$%^&*()'
    expected = '\\!\\@\\#\\$\\%\\^\\&\\*\\(\\)'
    assert_equal expected, Parselly.sanitize(input)
  end

  def test_mixed_input
    input = "-1a\x01b\0c!"
    expected = "-\\31 a\\1 b�c\\!"
    assert_equal expected, Parselly.sanitize(input)
  end

  def test_empty_string
    assert_equal '', Parselly.sanitize('')
  end

  def test_only_safe_characters
    input = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_'
    assert_equal input, Parselly.sanitize(input)
  end
end
