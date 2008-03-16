require File.dirname(__FILE__) + '/../test_helper'
require 'account_controller'

# Raise errors beyond the default web-based presentation
class AccountController; def rescue_action(e) raise e end; end

class AccountControllerTest < Test::Unit::TestCase
  
  fixtures :users
  
  def setup
    @controller = AccountController.new
    @request, @response = ActionController::TestRequest.new, ActionController::TestResponse.new
    @request.host = "localhost"
  end
  
  def test_auth_rolf
    @request.session['return-to'] = "http://localhost/bogus/location"

    post :login, "user_login" => "rolf", "user_password" => "testpassword"
    assert(@response.has_session_object?("user"))

    assert_equal @rolf, @response.session["user"]
    
    assert_equal("http://localhost/bogus/location", @response.redirect_url)
  end
  
  def test_signup
    @request.session['return-to'] = "http://localhost/bogus/location"

    post :signup, "user" => { "login" => "newbob", "password" => "newpassword", "password_confirmation" => "newpassword",
                              "email" => "nathan@collectivesource.com", "theme" => "NULL" }
    assert(@response.has_session_object?("user"))
    
    assert_equal("http://localhost/bogus/location", @response.redirect_url)
  end

  def test_bad_signup
    @request.session['return-to'] = "http://localhost/bogus/location"

    # Password doesn't match
    post :signup, "user" => { "login" => "newbob", "password" => "newpassword", "password_confirmation" => "wrong",
      "theme" => "NULL" }
    assert(find_record_in_template("user").errors.invalid?(:password))
    
    # No email
    post :signup, "user" => { "login" => "yo", "password" => "newpassword", "password_confirmation" => "newpassword",
      "theme" => "NULL" }
    assert(find_record_in_template("user").errors.invalid?(:login))

    # Bad password and no email
    post :signup, "user" => { "login" => "yo", "password" => "newpassword", "password_confirmation" => "wrong",
      "theme" => "NULL" }
    assert(find_record_in_template("user").errors.invalid?(:password))
    assert(find_record_in_template("user").errors.invalid?(:login))
  end
  
  def test_signup_theme_errors
    @request.session['return-to'] = "http://localhost/bogus/location"

    post :signup, "user" => { "login" => "spammer", "password" => "spammer", "password_confirmation" => "spammer",
                              "email" => "spam@spam.spam", "theme" => "" }
    assert(!@response.has_session_object?("user"))
    
    assert_equal("http://localhost/bogus/location", @response.redirect_url)

    post :signup, "user" => { "login" => "spammer", "password" => "spammer", "password_confirmation" => "spammer",
                              "email" => "spam@spam.spam", "theme" => "spammer" }
    assert(!@response.has_session_object?("user"))
    assert_redirected_to(:controller => "account", :action => "welcome")
  end

  def test_invalid_login
    post :login, "user_login" => "rolf", "user_password" => "not_correct"
     
    assert(!@response.has_session_object?("user"))
    
    assert(@response.has_template_object?("login"))
  end
  
#   def test_login_logoff
# 
#     post :login, "user_login" => "rolf", "user_password" => "testpassword"
#     assert(@response.has_session_object?("user"))
# 
#     get :logout_user
#     assert(!@response.has_session_object?("user"))
# 
#   end

  # Test autologin feature.
  def test_autologin
    #
    # First make sure test page that requires login fails without autologin cookie.
    get :test_autologin
    assert_response :redirect
    #
    # Make sure cookie is not set if clear remember_me box in login.
    post :login, {
      "user_login"    => "rolf",
      "user_password" => "testpassword",
      :user => { :remember_me => "" }
    }
    assert session['user']
    assert !cookies[:mo_user]
    session['user'] = nil
    get :test_autologin
    assert_response :redirect
    #
    # Now clear session and try again with remember_me box set.
    post :login, {
      "user_login"    => "rolf",
      "user_password" => "testpassword",
      :user => { :remember_me => "1" }
    }
    assert session['user']
    assert cookies['mo_user']
    #
    # And make sure autlogin will pick that cookie up and do its thing.
    session['user'] = nil
    @request.cookies['mo_user'] = cookies['mo_user']
    get :test_autologin
    assert_response :success
  end
end
