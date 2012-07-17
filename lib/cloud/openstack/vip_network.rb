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

      @logger.info("Associating server `#{server.id}' " \
                   "with floating IP `#{@ip}'")

      # Check if the OpenStack floating IP is allocated. If true, check
      # if it is associated to any server, so we can disassociate it
      # before associating it to the new server.
      address_id = nil
      addresses = openstack.addresses
      addresses.each do |address|
        if address.ip == @ip
          address.server = nil unless address.instance_id.nil?
          address.server = server
          address_id = address.id
          break
        end
      end
      if address_id.nil?
        cloud_error("OpenStack CPI: floating IP #{@ip} not allocated")
      end
    end

  end
end