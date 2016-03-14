module Spree
  module Event
    class Tracker

      INSTANCE_VARIABLES_KEYS = [:activity, :actor, :actor_type, :object, :object_type, :referrer]

      def initialize(arguments: {})
        set_instance_variables(arguments)
      end

      def set_instance_variables(arguments = {})
        INSTANCE_VARIABLES_KEYS.each { |key| instance_variable_set("@#{ key.to_s }", arguments[key]) }
      end
    end
  end
end