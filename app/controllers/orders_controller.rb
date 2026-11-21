class OrdersController < ApplicationController
  before_action :remove_unavailable_cart_items

  def add_item
    sku = Sku.visible.includes(configuration_groups: :options).find(params[:sku_id])
    if !params.key?(:option_ids) && sku.available_configuration_groups.any?
      return render json: { configuration_url: sku_path(sku, anchor: "sku-configuration-heading") }, status: :unprocessable_entity
    end
    selection = SkuConfigurationSelection.new(sku, params.fetch(:option_ids, []))
    return invalid_configuration unless selection.valid?

    key = selection.line_key
    cart[key] = cart.fetch(key, 0) + 1
    render json: { count: cart.values.sum }
  end

  def remove_item
    cart.delete(requested_line_key)
    render json: { count: cart.values.sum }
  end

  def update_item
    key = requested_line_key
    quantity = params[:quantity].to_i
    if quantity.positive?
      unless cart.key?(key)
        return invalid_configuration if params.key?(:line_key)
        sku = Sku.visible.find(params[:sku_id])
        return invalid_configuration if sku.available_configuration_groups.any?
        key = sku.id.to_s
      end
      cart[key] = quantity
    else
      cart.delete(key)
    end
    render json: { count: cart.values.sum }
  end

  def cart_items
    render json: {
      items: @available_cart_lines.map do |key, (sku, selection)|
        { id: sku.id, line_key: key, name: sku.localized_name, sku_code: sku.sku_code,
          quantity: cart.fetch(key), configuration: selection.snapshot }
      end,
      count: cart.values.sum
    }
  end

  def create
    if @removed_configuration || @available_cart_lines.empty?
      return render json: { success: false, message: t("sku_configurations.review_cart") }, status: :unprocessable_entity
    end

    @order = Order.new(order_params)
    @order.status = 'pending'
    @order.user = current_user if user_signed_in?
    if !@order.user && @order.email.present?
      @order.user = User.find_by(email: @order.email.strip.downcase)
    end
    @available_cart_lines.each do |key, (sku, selection)|
      @order.order_items.build(sku: sku, quantity: cart.fetch(key), configuration_snapshot: selection.snapshot)
    end
    if @order.save
      session[:cart] = {}
      render json: { success: true, message: "Order submitted successfully!" }
    else
      render json: { success: false, message: "Failed to submit order, please check your information." }, status: :unprocessable_entity
    end
  end

  private

  def cart
    session[:cart] ||= {}
  end

  def requested_line_key
    (params[:line_key] || params[:sku_id]).to_s
  end

  def invalid_configuration
    render json: { success: false, message: t("sku_configurations.invalid") }, status: :unprocessable_entity
  end

  def remove_unavailable_cart_items
    @available_cart_lines = {}
    return if cart.empty?

    sku_ids = cart.keys.map { |key| key.split(":", 2).first }.uniq
    skus = Sku.visible.includes(configuration_groups: :options).where(id: sku_ids).index_by { |sku| sku.id.to_s }
    cart.each_key do |key|
      sku_id, options = key.split(":", 2)
      sku = skus[sku_id]
      next unless sku
      selection = SkuConfigurationSelection.new(sku, options ? options.split(",") : [])
      @available_cart_lines[key] = [sku, selection] if selection.valid?
    end

    @removed_configuration = cart.keys.any? { |key| !@available_cart_lines.key?(key) && key.include?(":") }
    session[:cart] = cart.slice(*@available_cart_lines.keys)
  end

  def order_params
    params.permit(:name, :country, :phone, :email, :message)
  end
end
