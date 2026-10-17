module Dealer
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :ensure_dealer_access
    layout "dealer"

    private

    def ensure_dealer_access
      # Super admin can view dealer portal
      return if current_user.super_admin?

      # If user has no dealer status and not dealer, redirect or allow them to apply
      unless current_user.dealer? || current_user.dealer_pending? || current_user.dealer_applicant?
        redirect_to root_path, alert: "您当前不是经销商，如需加入请提交经销商申请。"
      end
    end
  end
end
