module Pusher
  module Saunalahti
    class Base < ::Pusher::Base
      PAGES = { signup: "settings/resellerLogin",
                signup_mbb: "settings/tilaus/mobiililaajakaista",
                signup_gsm: "settings/signup/gsms",
                visit_status_check: "settings/mnpNumberStatus"
              }

      PAGES.each do |name, link|
        define_method(name) do
          session.visit([app_host, link].join)
        end
      end

      def reseller_login
        signup
        session.fill_in("username", with: "test")
        session.fill_in("password", with: "test")
        session.find("[name='login_reseller']").click
      end

      def submit_step
        session.click_button "btn_navi_forward"
      end
    end
  end
end
