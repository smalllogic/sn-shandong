class Users::RegistrationsController < Devise::RegistrationsController
  protected

  def build_resource(hash = {})
    super
    if params[:user] && (params[:user][:apply_dealer] == "1" || params[:user][:apply_dealer] == true || params[:user][:apply_dealer] == "true")
      self.resource.dealer_status = "pending"
      self.resource.role = "user"
    end
  end

  def after_sign_up_path_for(resource)
    if resource.dealer_applicant?
      dealer_root_path
    else
      root_path
    end
  end
end
