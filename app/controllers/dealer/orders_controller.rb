module Dealer
  class OrdersController < BaseController
    def index
      @orders = current_user.orders.order(created_at: :desc)
      @orders = @orders.page(params[:page]).per(15) if defined?(Kaminari)
    end

    def show
      @order = current_user.orders.includes(order_items: :sku).find(params[:id])
    end
  end
end
