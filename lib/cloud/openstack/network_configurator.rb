# Copyright (c) 2012 Piston Cloud Computing, Inc.

module Bosh::OpenStackCloud
  ##
  # Represents OpenStack server network config. OpenStack server has single NIC
  # with dynamic IP address and (optionally) a single floating IP address
  # which server itself is not aware of (vip). Thus we should perform
  # a number of sanity checks for the network spec provided by director
  # to make sure we don't apply something OpenStack doesn't understand how to
  # deal with.
  #
  class NetworkConfigurator
    include Helpers

    ##
    # Creates new network spec
    #
    # @param [Hash] spec raw network spec passed by director
    # TODO Add network configuration examples
    def initialize(spec)
      unless spec.is_a?(Hash)
        raise ArgumentError, "Invalid spec, Hash expected, " \
                             "#{spec.class} provided"
      end

      @logger = Bosh::Clouds::Config.logger
      @dynamic_network = nil
      @vip_network = nil
      @security_groups = []

      spec.each_pair do |name, spec|
        network_type = spec["type"]

        case network_type
        when "dynamic"
          if @dynamic_network
            cloud_error("More than one dynamic network for `#{name}'")
          else
            @dynamic_network = DynamicNetwork.new(name, spec)
            # only extract security groups for dynamic networks
            extract_security_groups(spec)
          end
        when "vip"
          if @vip_network
            cloud_error("More than one vip network for `#{name}'")
          else
            @vip_network = VipNetwork.new(name, spec)
          end
        else
          cloud_error("Invalid network type `#{network_type}': OpenStack CPI " \
                      "can only handle `dynamic' and `vip' network types")
        end

      end

      if @dynamic_network.nil?
        cloud_error("At least one dynamic network should be defined")
      end
    end

    def configure(openstack, server)
      @dynamic_network.configure(openstack, server)

      if @vip_network
        @vip_network.configure(openstack, server)
      else
        # If there is no vip network we should disassociate any floating IP
        # currently held by server (as it might have had floating IP before)
        addresses = openstack.addresses
        addresses.each do |address|
          if address.instance_id == server.id
            @logger.info("Disassociating floating IP `#{address.ip}' " \
                         "from server `#{server.id}'")
            address.disassociate
          end
        end
      end
    end

    ##
    # Returns the security groups for this network configuration, or
    # the default security groups if the configuration does not contain
    # security groups
    # @param [Array] default Default security groups
    # @return [Array] security groups
    def security_groups(default)
      if @security_groups.empty? && default
        return default
      else
        return @security_groups
      end
    end

    ##
    # Extracts the security groups from the network configuration
    # @param [Hash] network_spec Network specification
    # @raise [ArgumentError] if the security groups in the network_spec
    #   is not an Array
    def extract_security_groups(spec)
      if spec && spec["cloud_properties"]
        cloud_properties = spec["cloud_properties"]
        if cloud_properties && cloud_properties["security_groups"]
          unless cloud_properties["security_groups"].is_a?(Array)
            raise ArgumentError, "security groups must be an Array"
          end
          @security_groups += cloud_properties["security_groups"]
        end
      end
    end

  end

end