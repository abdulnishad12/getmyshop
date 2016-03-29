class OrdersController < ApplicationController
  include CheckLoginConcern
  before_action :check_login
  protect_from_forgery except: [:paypal_hook]

  def address
    session[current_user.id] ||= {}
    session[current_user.id]["order"] = order_params

    @address = current_user.addresses.first_or_initialize(
      name: current_user.first_name + " " + current_user.last_name,
      email: current_user.email,
      phone: current_user.phone
    )
  end

  def summary
    @address = current_user.addresses.first_or_initialize
    @address.assign_attributes(address_params)
    if @address.valid?
      session[current_user.id]["address"] = @address
      @order = Order.new(session[current_user.id]["order"])
      render :summary
    else
      render :address
    end
  end

  def payment
  end

  def post_payment
    finalize_order_and_redirect
  end

  def finalize_order_and_redirect
    address, order = store_order_information

    if address && order
      clear_cart
      case params[:type]
      when "pay-on-delivery"
        redirect_to confirmation_orders_path
      when "paypal"
        redirect_to order.paypal_url(confirmation_orders_path)
      else
        # put 3rd option here
        redirect_to :back
      end
    else
      redirect_to :back, notice: "Could not create your order."
    end
  end

  def clear_cart
    session[current_user.id]["address"] = nil
    session[current_user.id]["order"] = nil
    cookies.delete(:cart)
  end

  def store_order_information
    address_params = session[current_user.id]["address"]
    address = current_user.addresses.first_or_initialize
    address.update_attributes(address_params)
    order = current_user.orders.create(
      session[current_user.id]["order"].merge(
        address_id: address.id,
        payment_method: params[:type],
        total_amount: cookies[:total_amount]
      )
    )

    [address, order]
  end

  def confirmation
    redirect_to root_path unless request.referer == payment_orders_url
  end

  def order_params
    params.require(:order).permit(
      :total_amount,
      order_items_attributes: [:order_id, :product_id, :quantity, :size]
    )
  end

  def address_params
    params.require(:address).permit(
      :id,
      :user_id,
      :name,
      :email,
      :address,
      :landmark,
      :gender,
      :phone,
      :state,
      :city,
      :country
    )
  end

  def past_orders
    @past_orders = current_user.orders
  end

  def paypal_hook
    params.permit!
    status = params[:payment_status]
    if status == "Completed"

    end
    render nothing: true
  end
end
