module Dealer
  class InquiriesController < BaseController
    def index
      @inquiries = current_user.contact_messages.order(created_at: :desc)
      @inquiries = @inquiries.page(params[:page]).per(15) if defined?(Kaminari)
    end

    def show
      @inquiry = current_user.contact_messages.find(params[:id])
    end
  end
end
