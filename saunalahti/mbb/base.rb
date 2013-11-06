#encoding: utf-8
module Pusher
  module Saunalahti
    module Mbb
      class Base < ::Pusher::Saunalahti::Base

        steps_config :login, :step1, :step2, :step3, :step4, :step5

        login :reseller_login
        step1 :signup_mbb, :check_order, :check_device_and_terms, :check_defaults, :submit_step
        step2 :fill_user_form, :submit_step
        step3 :submit_step
        step4 :confirm_order
        step5 :fill_result_details

        def initialize(pusher_id)
          super
          order_pusher.start!
        end

        def go
          parse_value
          begin
            run_steps([:login, :step1, :step2, :step3, :step4, :step5])
          rescue Exception => e
            ::Airbrake.notify(e) if Rails.env.production?
            self.order_pusher.error_message = e.message
            self.order_pusher.crash
          ensure
            save_result
          end
          self.order_pusher.finish
        end

        def check_order
          unless special?
            session.find("#subscriptionContent").all(".signupProductName").
                    find{ |els| els.text == @subscription_params["value"] }.find(:xpath, "..").find("input").click
          else
            order_name = /#{Regexp.escape(@subscription_params["value"])}/
            session.find("#campaignContent").all(".campaign_info").
                    find{ |el| el.text =~ order_name }.
                    find(".button_orange").click
                    sleep(4)
          end
        end

        def check_device_and_terms
          device_name = /#{Regexp.escape(@subscription_params["value_mbb_device"])}/
          session.find("#deviceContent").all("input[type='checkbox']").each{ |c_b| c_b.set(false) }
          sleep(2)
          container = session.find("#deviceContent").all(".signupProductList").find{ |el| el.text =~ device_name }
          container.find("input").click
          container.select(@subscription_params["value_mbb_term"])
          sleep(5)
        end

        def parse_value
          @subscription_params ||= JSON.parse(order_fields.mbb_subscription)
        end

        def check_defaults
          session.find("#additionalContent").
                  all(".signupProductList").find{ |el| el.text =~ /En halua lisäpalvelua/ }.find("input").click
          sleep(3)
        end

        def fill_user_form
          session.fill_in("ownerDetails:ownerFirstName", with: user[:first_name])
          session.fill_in("ownerDetails:ownerSurName", with: user[:last_name])
          session.fill_in("ownerDetails:ownerStreetAddress", with: user[:address])
          session.fill_in("ownerDetails:ownerPostCode", with: user[:zip_code])
          session.fill_in("ownerDetails:ownerPostOffice", with: user[:city])
          session.fill_in("ownerDetails:ownerMobilePhone", with: order_fields[:mobile].gsub("+358","0"))
          session.fill_in("ownerDetails:ownerEmail", with: user[:email])
          session.fill_in("ownerSsn:ssn", with: order_fields[:social_security_number_FIN])
          session.find("#billingEmailField").set(user[:email])
          Timeout::timeout(60){ loop { break unless session.has_selector?("#btn_navi_forward[disabled='disabled']") } }
        end

        def confirm_order
          session.check('wrapper:confirmationPanel:contracts:accept')
          submit_step if Rails.env.production? && ::Settings.application.pusher_confirm_order
          sleep(5)
        end

        def special?
          @subscription_params["value_mbb_special"]
        end

        def fill_result_details
          self.order_pusher.customer_id = session.find("[name='customerId']").text
          self.order_pusher.finished_at = Time.parse(session.find("#order-date").text)
          self.order_pusher.interface_number = session.all("td").find{|td| td.text =~ /Liittymänumero/ }.find(:xpath, "..").all("td").last.text
          self.order_pusher.save
        end
      end
    end
  end
end