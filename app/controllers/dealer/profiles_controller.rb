module Dealer
  class ProfilesController < BaseController
    def show
      @user = current_user
    end

    def edit
      @user = current_user
    end

    def update
      @user = current_user
      if params[:user][:password].blank?
        params[:user].delete(:password)
        params[:user].delete(:password_confirmation)
      end

      if @user.update(profile_params)
        bypass_sign_in(@user) if params[:user][:password].present?
        redirect_to dealer_profile_path, notice: "企业资料已更新。"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def profile_params
      params.require(:user).permit(:company_name, :contact_name, :phone, :country, :dealer_notes, :password, :password_confirmation)
    end
  end
end
