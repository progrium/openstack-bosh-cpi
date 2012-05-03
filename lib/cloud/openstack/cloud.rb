# Copyright (c) 2012 Piston Cloud Computing, Inc.

module Bosh::OpenStackCloud

  class Cloud < Bosh::Cloud
    include Helpers

    attr_reader :openstack

    ##
    # Initialize BOSH OpenStack CPI
    # @param [Hash] options CPI options
    #
    def initialize(options)
      @options = options.dup

      validate_options

      @logger = Bosh::Clouds::Config.logger

      @agent_properties = @options["agent"] || {}
      @openstack_properties = @options["openstack"]

      openstack_params = {
        :provider => "OpenStack",
        :openstack_auth_url => @openstack_properties["auth_url"],
        :openstack_username => @openstack_properties["username"],
        :openstack_api_key => @openstack_properties["api_key"],
        :openstack_tenant => @openstack_properties["tenant"]
      }

      @openstack = Fog::Compute.new(openstack_params)
    end

    ##
    # Creates OpenStack instance and waits until it's in running state
    # @param [String] agent_id Agent id associated with new VM
    # @param [String] stemcell_id AMI id that will be used
    #   to power on new instance
    # @param [Hash] resource_pool Resource pool specification
    # @param [Hash] network_spec Network specification, if it contains
    #  security groups they must be existing
    # @param [optional, Array] disk_locality List of disks that
    #   might be attached to this instance in the future, can be
    #   used as a placement hint (i.e. instance will only be created
    #   if resource pool availability zone is the same as disk
    #   availability zone)
    # @param [optional, Hash] environment Data to be merged into
    #   agent settings
    #
    # @return [String] created instance id
    def create_vm(agent_id, stemcell_id, resource_pool,
                  network_spec, disk_locality = nil, environment = nil)
      with_thread_name("create_vm(#{agent_id}, ...)") do
        if disk_locality
          @logger.debug("Disk locality is ignored by OpenStack CPI")
        end

        instance_params = {
          :image_id => stemcell_id,
          :flavor_id => resource_pool["instance_type"],
        }

        @logger.info("Creating new instance...")
        instance = @openstack.servers.create(instance_params)
        state = instance.state

        @logger.info("Creating new instance `#{instance.id}', " \
                     "state is `#{state}'")

        wait_resource(instance, state, :running)

        settings = initial_agent_settings(agent_id, network_spec, environment)

        instance.id
      end
    end

    ##
    # Terminates OpenStack server and waits until it reports as terminated
    # @param [String] vm_id Running server id
    def delete_vm(server_id)
      with_thread_name("delete_vm(#{server_id})") do
        server = @openstack.servers[server_id]

        server.destroy
        state = server.state

        @logger.info("Deleting server `#{server.id}', " \
                     "state is `#{state}'")

        wait_resource(server, state, :deleted)
      end
    end

    ##
    # Reboots OpenStack server
    # @param [String] server_id Running server id
    def reboot_vm(server_id)
      with_thread_name("reboot_vm(#{server_id})") do
        server = @openstack.servers[server_id]
        soft_reboot(server)
      end
    end

    ##
    # Creates a new OpenStack volume
    # @param [Integer] size disk size in MiB
    # @param [optional, String] instance_id vm id
    #        of the VM that this disk will be attached to
    # @return [String] created OpenStack volume id
    def create_disk(size, instance_id = nil)
      with_thread_name("create_disk(#{size}, #{instance_id})") do
        unless size.kind_of?(Integer)
          raise ArgumentError, "disk size needs to be an integer"
        end

        volume_params = {
          :size => (size / 1024.0).ceil,
        }

        volume = @openstack.volumes.create_volume(volume_params)
        state = volume.state

        @logger.info("Creating volume `#{volume.id}', " \
                     "state is `#{state}'")

        wait_resource(volume, state, :available)

        volume.id
      end
    end

    ##
    # Deletes OpenStack volume
    # @param [String] disk_id volume id
    # @raise [Bosh::Clouds::CloudError] if disk is not in available state
    # @return nil
    def delete_disk(disk_id)
      with_thread_name("delete_disk(#{disk_id})") do
        volume = @openstack.volumes[disk_id]
        state = volume.state

        if state != :available
          cloud_error("Cannot delete volume `#{volume.id}', state is #{state}")
        end

        volume.delete_volume

        begin
          state = volume.state
          @logger.info("Deleting volume `#{volume.id}', " \
                       "state is `#{state}'")

          wait_resource(volume, state, :deleted)
        rescue Fog::Compute::OpenStack::NotFound
        end

        @logger.info("Volume `#{disk_id}' has been deleted")
      end
    end

    def attach_disk(instance_id, disk_id)
      with_thread_name("attach_disk(#{instance_id}, #{disk_id})") do
        instance = @openstack.servers[instance_id]
        volume = @openstack.volumes[disk_id]

        device_name = instance.attach_volume(volume.id, instance.id, disk_id)

        update_agent_settings(instance) do |settings|
          settings["disks"] ||= {}
          settings["disks"]["persistent"] ||= {}
          settings["disks"]["persistent"][disk_id] = device_name
        end
      end
    end

    def detach_disk(instance_id, disk_id)
      with_thread_name("detach_disk(#{instance_id}, #{disk_id})") do
        instance = @openstack.servers[instance_id]
        volume = @openstack.volumes[disk_id]

        update_agent_settings(instance) do |settings|
          settings["disks"] ||= {}
          settings["disks"]["persistent"] ||= {}
          settings["disks"]["persistent"].delete(disk_id)
        end

        instance.detach_volume(instance.id, volume.id)

        @logger.info("Detached `#{disk_id}' from `#{instance_id}'")
      end
    end

    def configure_networks(instance_id, network_spec)
      not_implemented(:configure_networks)
    end

    def create_stemcell(image_path, cloud_properties)
      not_implemented(:create_stemcell)
    end

    def delete_stemcell(stemcell_id)
      not_implemented(:delete_stemcell)
    end

    def validate_deployment(old_manifest, new_manifest)
      not_implemented(:validate_deployment)
    end

    private

    ##
    # Generates initial agent settings. These settings will be read by agent
    # from the OS API on a target instance. Disk conventions are:
    # system disk: /dev/sda
    # ephemeral disk: /dev/sdb
    # Volumes can be configured to map to other device names later (sdf
    # through sdp, also some kernels will remap sd* to xvd*).
    #
    # @param [String] agent_id Agent id (will be picked up by agent to
    #   assume its identity
    # @param [Hash] network_spec Agent network spec
    # @param [Hash] environment
    # @return [Hash]
    def initial_agent_settings(agent_id, network_spec, environment)
      settings = {
        "vm" => {
          "name" => "vm-#{generate_unique_name}"
        },
        "agent_id" => agent_id,
        "networks" => network_spec,
        "disks" => {
          "system" => "/dev/sda",
          "ephemeral" => "/dev/sdb",
          "persistent" => {}
        }
      }

      settings["env"] = environment if environment
      settings.merge(@agent_properties)
    end

    def update_agent_settings(instance)
      unless block_given?
        raise ArgumentError, "block is not provided"
      end

      settings = @openstack.server(instance.id)
      yield settings
    end

    def generate_unique_name
      UUIDTools::UUID.random_create.to_s
    end

    ##
    # Soft reboots OpenStack server
    # @param [Fog::Compute::OpenStack::Server] OpenStack server
    def soft_reboot(server)
      server.reboot
    end

    ##
    # Hard reboots OpenStack server
    # @param [Fog::Compute::OpenStack::Server] OpenStack server
    def hard_reboot(server)
      server.reboot(type = 'HARD')
    end

    ##
    # Checks if options passed to CPI are valid and can actually
    # be used to create all required data structures etc.
    #
    def validate_options
      unless @options.has_key?("openstack") &&
          @options["openstack"].is_a?(Hash) &&
          @options["openstack"]["auth_url"] &&
          @options["openstack"]["username"] &&
          @options["openstack"]["api_key"] &&
          @options["openstack"]["tenant"]
        raise ArgumentError, "Invalid OpenStack configuration parameters"
      end
    end

  end

end
