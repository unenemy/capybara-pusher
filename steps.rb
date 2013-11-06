module Pusher
  module Steps

    def self.included(base)
      base.send(:include, ::Pusher::Steps::InstanceMethods)
      base.send(:extend, ::Pusher::Steps::ClassMethods)
      base.send(:init_pusher_steps_accessors)
    end

    module ClassMethods
      def init_pusher_steps_accessors
        cattr_accessor :steps
        cattr_accessor :retryable_activated, :retry_attempts_count

        attr_accessor :current_step
      end

      def steps_config(*array_of_steps)

        self.steps = array_of_steps
        steps.each do |step_name|
          define_singleton_method(step_name) do |*methods|
            define_method("#{step_name.to_s}_step") do
              self.current_step = step_name
              methods.each{ |method| send(method) }
            end
          end
        end
      end

      def retryable(activate, options)
        self.retryable_activated = activate
        self.retry_attempts_count = options[:retry_attempts] || 1
      end
    end

    module InstanceMethods
      def run_all_steps
        run_steps self.steps
      end

      def run_steps(steps_arr)
        steps_arr.each{ |step| run_step(step) }
      end

      def run_step(step)
        step_name, fail_action = parse_step_opts(step)
        begin
          self.send("#{step_name.to_s}_step")
        rescue => e
          rescue_fail(step_name, fail_action, e)
        end
        reset_attempts_count
      end

      def rescue_fail(step, action, error)
        case action
        when :retry
          if retryable_activated && can_be_retried?
            retry!
            run_step(step)
          else
            raise error
          end
        when :skip
           nil
        end
      end

      def parse_step_opts(step)
        step.is_a?(Hash) ? [step.keys.first, step.values.first[:fail]] :[step, :retry]
      end

      def reset_attempts_count
        @run_retried = 0 if retryable_activated
      end

      def retry!
        @run_retried += 1
      end

      def can_be_retried?
        run_retried <= retry_attempts_count
      end

      def run_retried
        @run_retried ||= 0
      end

    end
  end
end