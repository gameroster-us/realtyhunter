module API
	module V1

		class ListingsController < ApplicationController
			include API::V1::NestioInterface
			skip_authorize_resource
			skip_before_action :logged_in_user
			protect_from_forgery with: :null_session
			before_action :authenticate

			def index
				restrict_results
			end

			def show
				@listing = ResidentialUnit.find(params[:id])
			end
		
			# TODO: pull out into common methods
			def render_unauthorized
				self.headers['WWW-Authenticate'] = 'Token realm-"Agents"'

				respond_to do |format|
					format.json { render json: 'Bad credentials', status: 401 }
				end
			end

		protected
			def authenticate
				authenticate_token || render_unauthorized
			end

			def authenticate_token
				authed = false
				# check for token in the URL?
				if !authed && params[:token]
					@user = User.find_by(auth_token: params[:token])
					return @user ? true : false
				end

				authenticate_or_request_with_http_token('Agents') do |token, options|
					@user = User.find_by(auth_token: token)
					authed = true
				end
			end

			def restrict_results
				# 10 = residential, 20 = sales, 30 = commercial
				# default to residential
				listing_type = %w[10 20 30].include?(listing_params[:listing_type]) ? listing_params[:listing_type] : "10"
				# 10 - studio, 20 - 1 BR, 30 - 2 BR, 40 - 3 BR, 50 - 4+ BR, 80 - LOFT
				layout = %w[10 20 30 40 50 80].include?(listing_params[:layout]) ? listing_params[:layout] : ""
				# 10 - 1 B, 15 - 1.5 B, 20 - 2 B, 25 - 2.5 B, 30 - 3 B, 35 - 3.5+ B
				bathrooms = %w[10 15 20 25 30 35].include?(listing_params[:bathrooms]) ? listing_params[:bathrooms] : ""
				# cats allowed
				
				cats_allowed = %w[true false 0 1].include?(listing_params[:cats_allowed]) ? listing_params[:cats_allowed]: ""
				# dogs allowed
				dogs_allowed = %w[true false 0 1].include?(listing_params[:dogs_allowed]) ? listing_params[:dogs_allowed]: ""

				# sort order defaults to order by last udpated
				sort = %w[layout rent date_available updated status_updated].include?(listing_params[:sort]) ? listing_params[:sort] : "updated"
				# sort_dir
				sort_dir = %w[asc desc].include?(listing_params[:sort_dir]) ? listing_params[:sort_dir] : ""

				# pagination
				per_page = 50
				if listing_params[:per_page]
					if listing_params[:per_page] < 0 || listing_params[:per_page] > 50
						listing_params[:per_page] = 50
					end
				end
				
				# calls our API::V1::NestioInterface module located under /lib
				@listings = search(@user.company_id, {
					listing_type: listing_type,
					layout: layout,
					bathrooms: bathrooms,
					min_rent: listing_params[:min_rent],
					max_rent: listing_params[:max_rent],
					cats_allowed: cats_allowed,
					dogs_allowed: dogs_allowed,
					date_available_before: listing_params[:date_available_before],
					date_available_after: listing_params[:date_available_after],
					sort: sort,
					sort_dir: sort_dir,
					per_page: per_page,
					page: listing_params[:page]
					});
				#@listings = []
			end

			# Never trust parameters from the scary internet, only allow the white list through.
    	def listing_params
	      params.permit(:token, :pretty, :format, 
	      	:listing_type, :layout, :bathrooms, :min_rent, :max_rent,
	      	:cats_allowed, :dogs_allowed, :elevator, :doorman, :date_available_after, 
	      	:date_available_before, :laundry_in_building, :laundry_in_unit, 
	      	:has_photos, :featured, :sort, :sort_dir, :per_page,
	      	:neighborhoods => [], :geometry => [], :agents => [])
    end
		
		end
	end
end