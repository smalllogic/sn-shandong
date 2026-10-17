module Admin
  class DealersController < BaseController
    before_action :require_super_admin
    before_action :set_dealer, only: [:show, :edit, :update, :approve, :reject]

    def index
      @status = params[:status].presence || 'all'
      @dealers = User.order(created_at: :desc)
      case @status
      when 'pending'
        @dealers = @dealers.where(dealer_status: 'pending')
      when 'approved'
        @dealers = @dealers.where(dealer_status: 'approved').or(User.where(role: 'dealer'))
      when 'rejected'
        @dealers = @dealers.where(dealer_status: 'rejected')
      else
        @dealers = @dealers.dealers
      end
      @dealers = @dealers.page(params[:page]).per(20) if defined?(Kaminari)
    end

    def show
      @inquiries = @dealer.contact_messages.order(created_at: :desc)
      @orders = @dealer.orders.order(created_at: :desc)
    end

    def edit
    end

    def update
      if @dealer.update(dealer_params)
        redirect_to admin_dealer_path(@dealer), notice: "经销商信息已更新。"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def approve
      @dealer.approve_dealer!
      redirect_to admin_dealers_path(status: params[:status]), notice: "已批准 #{@dealer.display_name} 的经销商申请。"
    end

    def reject
      @dealer.reject_dealer!
      redirect_to admin_dealers_path(status: params[:status]), notice: "已拒绝 #{@dealer.display_name} 的经销商申请。"
    end

    private

    def set_dealer
      @dealer = User.find(params[:id])
    end

    def dealer_params
      params.require(:user).permit(:dealer_status, :company_name, :contact_name, :phone, :country, :dealer_notes, :role)
    end
  end
end
