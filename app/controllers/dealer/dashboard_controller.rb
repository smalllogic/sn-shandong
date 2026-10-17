module Dealer
  class DashboardController < BaseController
    def index
      @inquiries_count = current_user.contact_messages.count
      @orders_count = current_user.orders.count
      @recent_inquiries = current_user.contact_messages.order(created_at: :desc).limit(5)
      @recent_orders = current_user.orders.order(created_at: :desc).limit(5)
    end
  end
end
