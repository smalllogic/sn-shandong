module Admin
  class UsersController < BaseController
    before_action :require_super_admin
    before_action :set_user, only: [:edit, :update, :destroy, :promote]

    def index
      @users = User.order(created_at: :desc)
    end

    def edit
    end

    def update
      if @user.update(user_params)
        redirect_to admin_users_path, notice: "用户信息已更新。"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def promote
      if @user.update(role: "admin")
        redirect_to admin_users_path, notice: "用户已成功提升为小管理员。"
      else
        redirect_to admin_users_path, alert: @user.errors.full_messages.to_sentence
      end
    end

    def destroy
      if @user.destroy
        redirect_to admin_users_path, notice: "用户已删除。"
      else
        redirect_to admin_users_path, alert: @user.errors.full_messages.to_sentence
      end
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      params.require(:user).permit(:role).tap do |attributes|
        if attributes.key?(:role) && !%w[user editor admin].include?(attributes[:role])
          raise ActionController::BadRequest, "Unsupported role"
        end
      end
    end
  end
end
