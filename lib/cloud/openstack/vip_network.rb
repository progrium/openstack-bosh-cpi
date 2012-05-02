# Copyright (c) 2012 Piston Cloud Computing, Inc.

module Bosh::OpenStackCloud
  ##
  #
  class VipNetwork < Network

    ##
    # Creates a new vip network
    #
    # @param [String] name Network name
    # @param [Hash] spec Raw network spec
    def initialize(name, spec)
      super
    end

    ##
    # Configures vip network
    #
    # @param [Fog::Compute::OpenStack] openstack Fog OpenStack Compute client
    # @param [Fog::Compute::OpenStack::Server] server OpenStack server to configure
    def configure(openstack, server)
      if @ip.nil?
        cloud_error("No IP provided for vip network `#{@name}'")
      end

      @logger.info("Associating instance `#{server.id}' " \
                   "with floating IP `#{@ip}'")

      # New floating IP reservation supposed to clear the old one,
      # so no need to disassociate manually. Also, we don't check
      # if this IP is actually an allocated OpenStack floating IP, as
      # API call will fail in that case.
      # TODO: wrap error for non-existing floating IP?
      # TODO: poll instance until this IP is returned as its public IP?
      server.associate_address(@ip)
    end

  end
end