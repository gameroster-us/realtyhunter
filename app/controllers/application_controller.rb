class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
protect_from_forgery with: :exception
  include SessionsHelper
  before_filter :expire_hsts
  
  private
    # Confirms a logged-in user.
    def logged_in_user
      unless logged_in?
        store_location
        flash[:danger] = "Please log in."
        redirect_to login_url
      end
    end

	  def expire_hsts
  	  response.headers["Strict-Transport-Security"] = 'max-age=0'
  	end
end
