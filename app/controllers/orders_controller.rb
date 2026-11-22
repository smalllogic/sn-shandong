class OrdersController < ApplicationController
  def add_item
    sku = Sku.visible.includes(configuration_groups: :options).find(params[:sku_id])
    if !params.key?(:option_ids) && sku.available_configuration_groups.any?
      return render json: { configuration_url: sku_path(sku, anchor: "sku-configuration-heading") }, status: :unprocessable_entity
    end

    selection = SkuConfigurationSelection.new(sku, params.fetch(:option_ids, []))
    return invalid_configuration unless selection.valid?

    key = selection.line_key
    quantity = cart.fetch(key, 0) + 1
    return invalid_quantity if quantity > OrderItem::MAX_QUANTITY

    cart[key] = quantity
    cart_changed
  end

  def remove_item
    return cart_changed if cart.delete(requested_line_key)

    render json: { count: cart.values.sum }
  end

  def update_item
    key = requested_line_key
    quantity = Integer(params[:quantity].to_s, 10, exception: false)
    return invalid_quantity unless quantity&.between?(1, OrderItem::MAX_QUANTITY)
    return invalid_configuration unless cart.key?(key) && available_cart_lines.key?(key)

    cart[key] = quantity
    cart_changed
  end

  def cart_items
    render json: {
      items: cart.map do |key, quantity|
        sku, selection = available_cart_lines[key]
        sku ||= visible_cart_skus[key.split(":", 2).first]
        { id: sku&.id, line_key: key, name: sku&.localized_name, sku_code: sku&.sku_code,
          quantity: quantity, configuration: selection&.snapshot || [],
          unavailable: !selection, product_url: (sku_path(sku) if sku) }
      end,
      count: cart.values.sum
    }
  end

  def create
    key = submission_key
    return submitted if key && Order.exists?(submission_key: key)

    if cart.empty? || available_cart_lines.size != cart.size
      return render json: { success: false, message: t("sku_configurations.review_cart") }, status: :unprocessable_entity
    end

    order = Order.new(order_params.merge(status: "pending", user: current_user, submission_key: key))
    available_cart_lines.each do |line_key, (sku, selection)|
      order.order_items.build(sku: sku, quantity: cart.fetch(line_key), configuration_snapshot: selection.snapshot)
    end

    if order.save
      submitted
    else
      render json: { success: false, message: order.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    raise unless key && Order.exists?(submission_key: key)

    submitted
  end

  private

  def cart
    session[:cart] ||= {}
  end

  def cart_changed
    session[:inquiry_token] = SecureRandom.uuid
    render json: { count: cart.values.sum }
  end

  def submission_key
    session[:inquiry_token] ||= Digest::SHA256.hexdigest([session.id.to_s, cart.sort].to_json) if cart.any?
    token = session[:inquiry_token]
    Digest::SHA256.hexdigest([session.id.to_s, current_user&.id, token].to_json) if token
  end

  def submitted
    session[:cart] = {}
    render json: { success: true, message: t("sku_configurations.submitted") }
  end

  def requested_line_key
    (params[:line_key] || params[:sku_id]).to_s
  end

  def invalid_configuration
    render json: { success: false, message: t("sku_configurations.invalid") }, status: :unprocessable_entity
  end

  def invalid_quantity
    render json: { success: false, message: t("sku_configurations.invalid_quantity", max: OrderItem::MAX_QUANTITY) }, status: :unprocessable_entity
  end

  def available_cart_lines
    @available_cart_lines ||= begin
      cart.keys.each_with_object({}) do |key, lines|
        sku_id, options = key.split(":", 2)
        sku = visible_cart_skus[sku_id]
        next unless sku

        selection = SkuConfigurationSelection.new(sku, options ? options.split(",") : [])
        lines[key] = [sku, selection] if selection.valid?
      end
    end
  end

  def visible_cart_skus
    @visible_cart_skus ||= begin
      sku_ids = cart.keys.map { |key| key.split(":", 2).first }.uniq
      Sku.visible.includes(configuration_groups: :options).where(id: sku_ids).index_by { |sku| sku.id.to_s }
    end
  end

  def order_params
    params.permit(:name, :country, :phone, :email, :message)
  end
end
