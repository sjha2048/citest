require 'test_helper'
require 'jws_online_test_helper'

class JwsOnlineTest < ActionController::TestCase
  tests ModelsController

  include AuthenticatedTestHelper
  include JwsOnlineTestHelper

  test 'simulate button visibility' do
    model = Factory(:teusink_model, policy: Factory(:public_policy))
    get :show, id: model
    assert_response :success
    assert_select '#buttons a[href=?]', simulate_model_path(model, version: 1)

    model = Factory(:non_sbml_xml_model, policy: Factory(:public_policy))
    get :show, id: model
    assert_response :success
    assert_select '#buttons a[href=?]', simulate_model_path(model, version: 1), count: 0

    model = Factory(:teusink_model, policy: Factory(:publicly_viewable_policy))
    get :show, id: model
    assert_response :success
    assert_select '#buttons a[href=?]', simulate_model_path(model, version: 1), count: 0
  end

  test 'simulate' do
    model = Factory(:teusink_model, policy: Factory(:public_policy))
    get :simulate, id: model.id, version: model.version, constraint_based:'1'
    assert_response :success
    assert assigns(:simulate_url)

    url = assigns(:simulate_url)
    refute_nil url
    assert url =~ URI.regexp, "simulate url (#{url}) should be a valid url"
    assert_select 'iframe[src=?]', url
  end

  test 'simulate no constraint defined' do
    model = Factory(:teusink_model, policy: Factory(:public_policy))
    get :simulate, id: model.id, version: model.version
    assert_response :success
    refute assigns(:simulate_url)
    assert_select 'input[@type=checkbox]#constraint_based',count: 1
  end
end
