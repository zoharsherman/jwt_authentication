class JwtAuthentication::SessionsController < Devise::SessionsController
  include JwtAuthentication::Concerns::JwtControllerHelpers
  include JwtAuthentication::JwtAuthenticationHandler
  handle_jwt_authentication

  def create
    self.resource = warden.authenticate!({ scope: resource_name, recall: "#{controller_path}#new", store: false })
    sign_in(resource_name, resource)
    yield resource if block_given?

    token, expires = resource.jwt_token_and_expires(sign_in_params[:remember_me])
    send(:"set_jwt_cookie_for_#{resource_name}", token, expires)
    render json: { auth_token: token, resource: resource }
  end

  def destroy
    unless all_signed_out?
      Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name)
      yield if block_given?
    end
    send(:"destroy_jwt_cookie_for_#{resource_name}")

    render nothing: true, status: json_status(true)
  end

  def destroy_all
    current_entity = send(:"current_#{resource_name}")
    current_entity.regenerate_authentication_token! if current_entity
  end
end
