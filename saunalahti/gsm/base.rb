module Pusher
  module Saunalahti
    module Gsm
      class Base < ::Pusher::Saunalahti::Base

        steps_config :login, :step1, :step2, :step3, :step4, :step5, :step6

        login :reseller_login
        step1 :gsm_login
        step2 :gsm_process
        step3 :check_product, :check_package, :fill_dialing
        step4 :fill_subscription_info
        step5 :confirm_order
        step6 :fill_result_details

        retryable :true, attempts: 4

        def initialize(pusher_id)
          super
          order_pusher.start!
        end

        def go
          begin
            run_steps([{ login: { fail: :skip } },
                         :step1, :step2, :step3,
                         :step4, { step4: { fail: :skip } },
                         :step5, :step6])
          rescue Exception => e
            ::Airbrake.notify(e) if Rails.env.production?
            self.order_pusher.error_message = e.message
            self.order_pusher.crash
          ensure
            save_result
          end
          self.order_pusher.finish
        end

        def gsm_login
          signup_gsm
          session.choose("customer_type_consumer")
          session.fill_in("firstname", with: user[:first_name])
          session.fill_in("lastname", with: user[:last_name])
          session.fill_in("ssn", with: order_fields[:social_security_number_FIN])
          session.click_button "btn_navi_forward"
        end

        def gsm_process
          session.choose("radio_email")
          session.fill_in("b_email", with: user.email)
          session.fill_in("b_email", with: user[:email])
          session.click_button "btn_navi_forward"
        end

        def check_product
          value = order_fields[:saunalahti_subscription]
          str = JSON.parse(value)["value"] || value
          p_name = /#{Regexp.escape(str)}/
          products = session.all(:xpath, "//label[@class='product_label']")
          el = products.find{|e| e.text =~ p_name}
          el.find(:xpath, "..").find(:xpath, "./input").click
          sleep(2)
        end

        def check_package
          session.find("#select_sim_head > #ss_icon").click
          value = order_fields[:SIM_card_type]
          pack_name = JSON.parse(value)["value"] || value
          el = session.find(:xpath, "//*[@id='select_sim_type']/div/*/*/*/*/b[contains(., '#{pack_name}')]").find(:xpath, "../../td/input")
          el.click
        end

        def fill_dialing
          session.find("#existing[name='number_port_selection']").click
          session.fill_in("existing_number", with: order_fields[:number_transfer])
          session.choose("id_mnp_fixed_term_contract1")
          session.choose("directory_public")
          submit_step
        end

        def fill_subscription_info
          session.fill_in("firstname", with: user[:first_name])
          session.fill_in("lastname", with: user[:last_name])
          session.fill_in("address", with: user[:address])
          session.fill_in("postalcode", with: user[:zip_code])
          session.fill_in("city", with: user[:city])
          session.fill_in("email", with: user[:email])
          session.fill_in("ssn", with: order_fields[:social_security_number_FIN])
          session.check("generatepw")
          submit_step
        end

        def confirm_order
          session.check("accept_terms_prc")
          submit_step if Rails.env.production? && ::Settings.application.pusher_confirm_order
        end

        def fill_result_details
           self.order_pusher.gsm_number = session.find("#gsmNumber").text
           self.order_pusher.customer_id = session.find("#userId").text
           self.order_pusher.finished_at = Time.now
           self.order_pusher.save
        end
      end
    end
  end
end