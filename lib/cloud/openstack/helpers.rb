# Copyright (c) 2012 Piston Cloud Computing, Inc.

module Bosh::OpenStackCloud

  module Helpers

    DEFAULT_TIMEOUT = 3600

    #
    # Raises CloudError exception
    #
    def cloud_error(message)
      @logger.error(message) if @logger
      raise Bosh::Clouds::CloudError, message
    end

    #
    # Waits for a resource to be on a target state
    #
    def wait_resource(resource, start_state, target_state, state_method = :status, timeout = DEFAULT_TIMEOUT)

      started_at = Time.now
      state = resource.send(state_method)
      desc = resource.class.name.split("::").last.to_s + " " + resource.id.to_s

      while state.to_sym != target_state
        duration = Time.now - started_at

        if duration > timeout
          cloud_error("Timed out waiting for #{desc} to be #{target_state}")
        end

        @logger.debug("Waiting for #{desc} to be #{target_state} (#{duration})") if @logger

        sleep(1)

        if resource.reload.nil?
          state = target_state
        else
          state = resource.send(state_method)
        end
      end

      @logger.info("#{desc} is #{target_state} after #{Time.now - started_at}s") if @logger
    end

  end

end
