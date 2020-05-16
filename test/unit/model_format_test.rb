require 'test_helper'

class ModelFormatTest < ActiveSupport::TestCase
  fixtures :model_formats

  test 'validation' do
    existing = model_formats(:SBML)
    m = ModelFormat.new(title: existing.title)

    assert !m.valid?
    m.title = ''
    assert !m.valid?
    m.title = 'zxzxclzxczxcczx'
    assert m.valid?
  end
end
