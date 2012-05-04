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
    def wait_resource(resource,
                      resource_id,
                      start_state,
                      target_state,
                      state_method = :get,
                      timeout = DEFAULT_TIMEOUT)

      started_at = Time.now
      state = resource.send(state_method, resource_id).status.downcase
      desc = resource.class.name + " " + resource_id.to_s

      while state != target_state
        duration = Time.now - started_at

        if duration > timeout
          cloud_error("Timed out waiting for #{desc} to be #{target_state}")
        end


        @logger.debug("Waiting for #{desc} to be #{target_state} (#{duration})") if @logger

        sleep(1)

        resource_state = resource.send(state_method, resource_id)
        if resource_state.nil?
          state = target_state
        else
          state = resource_state.status.downcase
        end
      end

      if state == target_state
        @logger.info("#{desc} is #{target_state} after #{Time.now - started_at}s") if @logger
      else
        cloud_error("#{desc} is #{state}, expected to be #{target_state}")
      end
    end
  end

end
