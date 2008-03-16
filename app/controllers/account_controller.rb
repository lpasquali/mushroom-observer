class AccountController < ApplicationController
  before_filter :login_required, :only => :test_autologin

  def login
    case request.method
      when :get
        @login = ""
        @remember = true
      when :post
        user = User.authenticate(params['user_login'], params['user_password'])
        @remember = params['user'] && params['user']['remember_me'] == "1"
        if session['user'] = user
          logger.warn("%s, %s, %s" % [user.login, params['user_login'], params['user_password']])
          flash_notice "Login successful."
          user.last_login = Time.now
          user.save
          # ---AUTOLOGIN---
          if @remember
            set_autologin_cookie(user)
          else
            clear_autologin_cookie
          end
          flash[:params] = params
          redirect_back_or_default :action => "welcome"
        else
          @login = params['user_login']
          flash_error "Login unsuccessful."
        end
    end
    @hiddens = []
    if flash[:params]
      flash[:params].each do |obj,val|
        hide_params(val, @hiddens, obj.to_s) if val.is_a?(Hash)
      end
    end
  end

  # Parameters from page that redirected to login are preserved in
  # flash[:params].  I store them in the login page as hidden fields.
  # When user logs in, it puts these params back into flash[:params]
  # and redirects to the original page.  The login_required "before"
  # filter will then merge them back into params[] automatically.
  # This method flattens the params structure into a simple array.
  def hide_params(obj, out, prefix)
    if !obj.is_a?(Hash)
      id    = prefix.gsub(/\[/, "_").gsub(/\]/, "")
      name  = prefix
      value = obj.to_s
      out << [id, name, value]
    else
      obj.each do |k,v|
        hide_params(v, out, "#{prefix}[#{k.to_s}]")
      end
    end
  end

  def signup
    case request.method
      when :get
        @user = User.new
      when :post
        theme = params['user']['theme']
        login = params['user']['login']
        valid_themes = CSS + ["NULL"]
        if valid_themes.member?(theme) and (login != 'test_denied')
          @user = User.new(params['user'])
          @user.created = Time.now
          @user.last_login = @user.created
          @user.change_rows(5)
          @user.change_columns(3)
          if @user.save
            session['user'] = User.authenticate(@user.login, params['user']['password'])
            flash_notice "Signup successful.  Verification sent to your email account."
            AccountMailer.deliver_verify(@user)
            redirect_back_or_default :action => "welcome"
          else
            flash_object_errors(@user)
          end
        else
          AccountMailer.deliver_denied(params['user'])
          redirect_back_or_default :action => "welcome"
        end
    end
  end

  def email_new_password
    case request.method
      when :get
        @user = User.new
      when :post
        @login = params['user']['login']
        @user = User.find(:first, :conditions => ["login = ?", @login])
        if @user.nil?
          flash_error "Unable to find the user '#{@login}'."
        else
          password = random_password(10)
          @user.change_password(password)
          if @user.save
            session['user'] = User.authenticate(@user.login, params['user']['password'])
            flash_notice "Password successfully changed.  New password has been sent to your email account."
            AccountMailer.deliver_new_password(@user, password)
            @hiddens = []
            render :action => "login"
          else
            flash_object_errors(@user)
          end
        end
    end
  end

  def prefs
    @user = session['user']
    if @user
      case request.method
        when :get
          @user = User.find(@user.id) # Make sure we have the latest version of the user
          session['user'] = @user
        when :post
          @user.change_email(params['user']['email'])
          @user.change_name(params['user']['name'])
          @user.html_email = params['user']['html_email']
          @user.feature_email = params['user']['feature_email']
          @user.comment_email = params['user']['comment_email']
          @user.commercial_email = params['user']['commercial_email']
          @user.question_email = params['user']['question_email']
          @user.change_theme(params['user']['theme'])
          @user.change_rows(params['user']['rows'])
          @user.change_columns(params['user']['columns'])
          @user.alternate_rows = params['user']['alternate_rows']
          @user.alternate_columns = params['user']['alternate_columns']
          @user.vertical_layout = params['user']['vertical_layout']
          @user.license_id = params['user']['license_id'].to_i
          password = params['user']['password']
          error = false
          if password
            if password == params['user']['password_confirmation']
              @user.change_password(password)
            else
              error = true
              flash_error "Password and confirmation did not match."
            end
          end
          if error || !@user.save
            flash_object_errors(@user)
          else
            flash_notice "Preferences updated."
            redirect_back_or_default :action => "welcome"
          end
      end
      @licenses = License.current_names_and_ids(@user.license)
    else
      store_location
      access_denied
    end
  end

  def delete
    if check_permission(0)
      if params['id']
        @user = User.find(params['id'])
        @user.destroy
      end
    end
    redirect_back_or_default :action => "welcome"
  end

  def logout_user
    @user = session['user'] = nil
    # ---AUTOLOGIN---
    clear_autologin_cookie
  end

  def welcome
  end

  def reverify
  end

  def verify
    if params['id']
      @user = User.find(params['id'])
      @user.verified = Time.now
      @user.save
      if session['user'] && (session['user'].id == @user.id)
        session['user'].verified = Time.now
      end
    else
      render :action => "reverify"
    end
  end

  def no_feature_email
    if login_check params['id']
      @user.feature_email = false
      if @user.save
        flash_notice "Automated feature email disabled for #{@user.unique_text_name}."
      end
      user = session['user']
      session['user'].feature_email = false
    end
  end

  def no_question_email
    if login_check params['id']
      @user.question_email = false
      if @user.save
        flash_notice "Question email disabled for #{@user.unique_text_name}."
      end
      user = session['user']
      session['user'].question_email = false
    end
  end

  def no_commercial_email
    if login_check params['id']
      @user.commercial_email = false
      if @user.save
        flash_notice "Commercial email inquiries disabled for #{@user.unique_text_name}."
      end
      user = session['user']
      session['user'].commercial_email = false
    end
  end

  def no_comment_email
    if login_check params['id']
      @user.comment_email = false
      if @user.save
        flash_notice "Comment email notifications disabled for #{@user.unique_text_name}."
      end
      user = session['user']
      session['user'].comment_email = false
    end
  end

  def test_verify
    user = session['user']
    email = AccountMailer.create_verify(user)
    render(:text => "<pre>" + email.encoded + "</pre>")
  end

  def send_verify
    AccountMailer.deliver_verify(session['user'])
    flash_notice "Verification sent to your email account."
    redirect_back_or_default :action => "welcome"
  end

  protected

  # Make sure the given user is the one that's logged in.  If no one is logged in
  # then give them a chance to login.
  def login_check(id)
    result = !session['user'].nil?
    if result
      # Undo the store_location
      session['return-to'] = url_for :controller => 'observer', :action => 'index'
      if id
        @user = User.find(id)
        if @user != session['user']
          flash_error "Permission denied."
          result = false
        end
      else
        redirect_to :action => 'prefs'
        result = false
      end
    else
      store_location
      access_denied
    end
    result
  end

end
