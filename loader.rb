module Pusher
  class Loader

    def initialize(order)
      @order = order
      return unless parse_for_class(@order.fields["pusher_id"])
      start_pusher_job
    end

    def start_pusher_job
      create_pusher_instance
      @pusher_instance.start_worker
    end

    def create_pusher_instance
      @pusher_instance = @pusher_class.create(order_id: @order.id) if @pusher_class
    end

    def parse_for_class(pusher_name)
      return unless pusher_name
      @pusher_class ||= "OrderPusher::#{pusher_name.try(:classify)}".safe_constantize
    end
  end
end