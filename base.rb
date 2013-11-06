#encoding:utf-8
require 'capybara'
require 'capybara/session'
require 'capybara/poltergeist'
require 'wicked_pdf'
require "selenium-webdriver" if Rails.env.development?

module Pusher
  class Base
    include ::Pusher::Steps
    attr_accessor :user, :order, :order_pusher, :order_fields
    cattr_accessor :session, :app_host

    def save_result
      pdf_path = File.join([Rails.root,"tmp", "#{order_pusher.id}_result.pdf"])
      jpeg_path = File.join([Rails.root,"tmp", "#{order_pusher.id}_result.jpeg"])
      session.save_screenshot(jpeg_path, full: true)
      session.save_screenshot(pdf_path)

      File.open(pdf_path, 'rb') do |file|
        self.order_pusher.result_pdf = file
      end

      File.open(jpeg_path, 'rb') do |file|
        self.order_pusher.result_jpeg = file
      end

      order_pusher.save!
    end

    def initialize(pusher_id)
      init_session
      self.order_pusher = OrderPusher.includes(order: :user).find(pusher_id)
      init_order
      init_user
    end

    def init_session
      if Rails.env.production?
        Capybara.register_driver :poltergeist do |app|
          Capybara::Poltergeist::Driver.new(app, js_errors: false)
        end
        self.session = Capybara::Session.new(:poltergeist)
      else
        self.session = Capybara::Session.new(:selenium)
      end
      self.app_host = "https://oma.saunalahti.fi/"
    end

    def init_user
      self.user = order_pusher.order.participation.fields
    end

    def init_order
      self.order_fields = order_pusher.order.fields
    end
  end
end