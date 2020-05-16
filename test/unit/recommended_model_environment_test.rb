require 'test_helper'

class RecommendedModelEnvironmentTest < ActiveSupport::TestCase
  fixtures :recommended_model_environments

  test 'validation' do
    existing = recommended_model_environments(:jws)
    e = RecommendedModelEnvironment.new(title: existing.title)

    assert !e.valid?
    e.title = ''
    assert !e.valid?
    e.title = 'zxzxclzxczxcczx'
    assert e.valid?
  end
end
