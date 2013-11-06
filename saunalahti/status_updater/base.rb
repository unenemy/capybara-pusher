#encoding:utf-8
module Pusher
  module Saunalahti
    module StatusUpdater
      class Base < Pusher::Saunalahti::Base
        steps_config :login, :step1, :step2, :step3, :step4

        login :reseller_login
        step1 :visit_status_check
        step2 :search_product
        step3 :grab_values
        step4 :update_oder_state

        DICTIONARY = { "Odottaa as. yhteydenottoa"  => { translation: "Waiting for customer to contact", action: :wait_contact },
                       "Odottaa postin kuittausta." => { translation: "Delivered but not in use", action: :deliver },
                       "Valmis"                     => { translation: "In Use", action: :complete },
                       "Toimitettu"                 => { translation: "Delivered", action: :complete },
                       "Virhe"                      => { translation: "Error", action: :operator_cancel },
                       "Hylätty/peruutettu"         => { translation: "Canceled", action: :user_cancel }

        }

        def initialize(order_id)
          init_session
          @order = User::Order.find(order_id)
        end

        def go
          begin
            run_all_steps
          rescue Exception => e
            ::Airbrake.notify(e) if Rails.env.production?
            @order.fields.state_message = e
            @order.save
          end
        end

        def search_product
          session.fill_in("msgnumber", with: search_info)
          session.find("[name='doQuery']").click
        end

        def search_info
          @order.pusher.gsm_number || @order.pusher.interface_number
        end

        def grab_values
          @result, @time, @details = parse_values
        end

        def parse_values
          row = session.all("td").find{|td| td.text == "Tila"}
          return unless row
          row = row.find(:xpath, "../following-sibling::tr")
          (1..3).map{ |i| row.find(:xpath, "./td[#{i}]").text }
        end

        def update_oder_state
          return unless @result
          take_order_action
          message = "#{DICTIONARY[@result][:translation]}: #{@time}"
          message = [message, @details].join(", ") unless @details.blank?
          @order.fields.state_message = message
          @order.save
        end

        def take_order_action
          action = (DICTIONARY[@result][:action])
          case action
          when :deliver
            @order.try_to_expire_on_deliver
          when :wait_contact
            @order.try_to_expire_on_wait
          else
            @order.send(action)
          end
        end
      end
    end
  end
end