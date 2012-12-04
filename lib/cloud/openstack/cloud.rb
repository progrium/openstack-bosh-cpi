# Copyright (c) 2012 Piston Cloud Computing, Inc.

module Bosh::OpenStackCloud

  class Cloud < Bosh::Cloud
    include Helpers

    DEFAULT_AVAILABILITY_ZONE = "nova"
    DEVICE_POLL_TIMEOUT = 60 # seconds
    METADATA_TIMEOUT = 5 # seconds

    attr_reader :openstack
    attr_reader :registry
    attr_reader :glance

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
      @registry_properties = @options["registry"]

      @default_key_name = @openstack_properties["default_key_name"]
      @default_security_groups = @openstack_properties["default_security_groups"]

      openstack_params = {
        :provider => "OpenStack",
        :openstack_auth_url => @openstack_properties["auth_url"],
        :openstack_username => @openstack_properties["username"],
        :openstack_api_key => @openstack_properties["api_key"],
        :openstack_tenant => @openstack_properties["tenant"]
      }
      @openstack = Fog::Compute.new(openstack_params)
      @glance = Fog::Image.new(openstack_params)

      registry_endpoint = @registry_properties["endpoint"]
      registry_user = @registry_properties["user"]
      registry_password = @registry_properties["password"]
      @registry = RegistryClient.new(registry_endpoint,
                                     registry_user,
                                     registry_password)

      @metadata_lock = Mutex.new
    end

    ##
    # Creates a new OpenStack Image using stemcell image.
    # @param [String] image_path local filesystem path to a stemcell image
    # @param [Hash] cloud_properties CPI-specific properties
    def create_stemcell(image_path, cloud_properties)
      with_thread_name("create_stemcell(#{image_path}...)") do
        begin
          Dir.mktmpdir do |tmp_dir|
            @logger.info("Extracting stemcell to `#{tmp_dir}'...")
            image_name = "BOSH-#{generate_unique_name}"

            # 1. Unpack image to temp directory
            unpack_image(tmp_dir, image_path)
            root_image = File.join(tmp_dir, "root.img")

            # 2. If image contains a kernel file, upload it
            kernel_id = nil
            if cloud_properties["kernel_id"]
              kernel_id = cloud_properties["kernel_id"]
            elsif cloud_properties["kernel_file"]
              kernel_image = File.join(tmp_dir, cloud_properties["kernel_file"])
              unless File.exists?(kernel_image)
                cloud_error("Kernel image is missing from stemcell archive")
              end
              kernel_params = {
                :name => "#{image_name}-AKI",
                :disk_format => "aki",
                :container_format => "aki",
                :location => kernel_image,
                :properties => {
                  :stemcell => image_name
                }
              }
              kernel_id = upload_image(kernel_params)
            end

            # 3. If image contains a ramdisk file, upload it
            ramdisk_id = nil
            if cloud_properties["ramdisk_id"]
              ramdisk_id = cloud_properties["ramdisk_id"]
            elsif cloud_properties["ramdisk_file"]
              ramdisk_image = File.join(tmp_dir, cloud_properties["ramdisk_file"])
              unless File.exists?(kernel_image)
                cloud_error("Ramdisk image is missing from stemcell archive")
              end
              ramdisk_params = {
                :name => "#{image_name}-ARI",
                :disk_format => "ari",
                :container_format => "ari",
                :location => ramdisk_image,
                :properties => {
                  :stemcell => image_name
                }
              }
              ramdisk_id = upload_image(ramdisk_params)
            end

            # 4. Upload image using Glance service
            image_params = {
              :name => image_name,
              :disk_format => cloud_properties["disk_format"],
              :container_format => cloud_properties["container_format"],
              :location => root_image,
              :is_public => true
            }
            image_properties = {}
            image_properties[:kernel_id] = kernel_id if kernel_id
            image_properties[:ramdisk_id] = ramdisk_id if ramdisk_id
            if cloud_properties["name"]
              image_properties[:stemcell_name] = cloud_properties["name"]
            end
            if cloud_properties["version"]
              image_properties[:stemcell_version] = cloud_properties["version"]
            end
            image_params[:properties] = image_properties unless image_properties.empty?

            upload_image(image_params)
          end
        rescue => e
          @logger.error(e)
          raise e
        end
      end
    end

    ##
    # Deletes a stemcell
    # @param [String] stemcell stemcell id that was once returned by {#create_stemcell}
    def delete_stemcell(stemcell_id)
      with_thread_name("delete_stemcell(#{stemcell_id})") do
        @logger.info("Deleting stemcell `#{stemcell_id}'...")
        image = @glance.images.find_by_id(stemcell_id)

        kernel_id = image.properties["kernel_id"]
        if kernel_id
          kernel = @glance.images.find_by_id(kernel_id)
          if kernel.properties["stemcell"]
            if kernel.properties["stemcell"] == image.name
              @logger.info("Deleting stemcell kernel `#{stemcell_id}'...")
              kernel.destroy
            end
          end
        end

        ramdisk_id = image.properties["ramdisk_id"]
        if ramdisk_id
          ramdisk = @glance.images.find_by_id(ramdisk_id)
          if ramdisk.properties["stemcell"]
            if ramdisk.properties["stemcell"] == image.name
              @logger.info("Deleting stemcell ramdisk `#{stemcell_id}'...")
              ramdisk.destroy
            end
          end
        end

        image.destroy
      end
    end

    ##
    # Creates an OpenStack server and waits until it's in running state
    # @param [String] agent_id Agent id associated with new VM
    # @param [String] stemcell_id AMI id that will be used to power on new server
    # @param [Hash] resource_pool Resource pool specification
    # @param [Hash] network_spec Network specification, if it contains security groups they must be existing
    # @param [optional, Array] disk_locality List of disks that might be attached to this server in the future,
    #  can be used as a placement hint (i.e. server will only be created if resource pool availability zone is
    #  the same as disk availability zone)
    # @param [optional, Hash] environment Data to be merged into agent settings
    # @return [String] created server id
    def create_vm(agent_id, stemcell_id, resource_pool,
                  network_spec = nil, disk_locality = nil, environment = nil)
      with_thread_name("create_vm(#{agent_id}, ...)") do
        network_configurator = NetworkConfigurator.new(network_spec)

        server_name = "vm-#{generate_unique_name}"
        metadata = {
          "registry" => {
            "endpoint" => @registry.endpoint
          },
          "server" => {
            "name" => server_name
          }
        }

        if disk_locality
          # TODO: use as hint for availability zones
          @logger.debug("Disk locality is ignored by OpenStack CPI")
        end

        security_groups = network_configurator.security_groups(@default_security_groups)
        @logger.debug("using security groups: #{security_groups.join(', ')}")

        image = @openstack.images.find { |i| i.id == stemcell_id }
        if image.nil?
          cloud_error("OpenStack CPI: image #{stemcell_id} not found")
        end

        flavor = @openstack.flavors.find { |f| f.name == resource_pool["instance_type"] }
        if flavor.nil?
          cloud_error("OpenStack CPI: flavor #{resource_pool["instance_type"]} not found")
        end

        server_params = {
          :name => server_name,
          :image_ref => image.id,
          :flavor_ref => flavor.id,
          :key_name => resource_pool["key_name"] || @default_key_name,
          :security_groups => security_groups,
          :user_data => Yajl::Encoder.encode(metadata)
        }

        availability_zone = resource_pool["availability_zone"]
        if availability_zone
          server_params[:availability_zone] = availability_zone
        end

        @logger.info("Creating new server...")
        server = @openstack.servers.create(server_params)

        @logger.info("Creating new server `#{server.id}'...")
        wait_resource(server, :active, :state)

        @logger.info("Configuring network for `#{server.id}'...")
        network_configurator.configure(@openstack, server)

        @logger.info("Updating server settings for `#{server.id}'...")
        settings = initial_agent_settings(server_name, agent_id, network_spec, environment)
        @registry.update_settings(server.name, settings)

        server.id.to_s
      end
    end

    ##
    # Terminates an OpenStack server and waits until it reports as terminated
    # @param [String] server_id Running OpenStack server id
    def delete_vm(server_id)
      with_thread_name("delete_vm(#{server_id})") do
        server = @openstack.servers.get(server_id)
        @logger.info("Deleting server `#{server_id}'...")
        if server
          server.destroy
          wait_resource(server, :terminated, :state, true)

          @logger.info("Deleting server settings for `#{server.id}'...")
          @registry.delete_settings(server.name)
        end
      end
    end

    ##
    # Reboots an OpenStack Server
    # @param [String] server_id Running OpenStack server id
    def reboot_vm(server_id)
      with_thread_name("reboot_vm(#{server_id})") do
        server = @openstack.servers.get(server_id)
        soft_reboot(server)
      end
    end

    ##
    # Configures networking on existing OpenStack server
    #
    # @param [String] server_id Running OpenStack server id
    # @param [Hash] network_spec Raw network spec passed by director
    def configure_networks(server_id, network_spec)
      with_thread_name("configure_networks(#{server_id}, ...)") do
        @logger.info("Configuring `#{server_id}' to use the following " \
                     "network settings: #{network_spec.pretty_inspect}")

        network_configurator = NetworkConfigurator.new(network_spec)
        server = @openstack.servers.get(server_id)

        sg = @openstack.list_security_groups(server_id).body["security_groups"]
        actual = sg.collect { |s| s["name"] }.sort
        new = network_configurator.security_groups(@default_security_groups)

        # If the security groups change, we need to recreate the VM
        # as you can't change the security group of a running server,
        # we need to send the InstanceUpdater a request to do it for us
        unless actual == new
          raise Bosh::Clouds::NotSupported,
                "security groups change requires VM recreation: %s to %s" %
                [actual.join(", "), new.join(", ")]
        end

        network_configurator.configure(@openstack, server)

        update_agent_settings(server) do |settings|
          settings["networks"] = network_spec
        end
      end
    end

    ##
    # Creates a new OpenStack volume
    # @param [Integer] size disk size in MiB
    # @param [optional, String] server_id vm id of the VM that this disk will be attached to
    # @return [String] created OpenStack volume id
    def create_disk(size, server_id = nil)
      with_thread_name("create_disk(#{size}, #{server_id})") do
        unless size.kind_of?(Integer)
          raise ArgumentError, "disk size needs to be an integer"
        end

        if (size < 1024)
          cloud_error("OpenStack CPI minimum disk size is 1 GiB")
        end

        if (size > 1024 * 1000)
          cloud_error("OpenStack CPI maximum disk size is 1 TiB")
        end

        if server_id
          server = @openstack.servers.get(server_id)
          availability_zone = server.availability_zone
        else
          availability_zone = DEFAULT_AVAILABILITY_ZONE
        end

        volume_params = {
          :name => "volume-#{generate_unique_name}",
          :description => "",
          :size => (size / 1024.0).ceil,
          :availability_zone => availability_zone
        }

        @logger.info("Creating new volume...")
        volume = @openstack.volumes.create(volume_params)

        @logger.info("Creating new volume `#{volume.id}'...")
        wait_resource(volume, :available)

        volume.id.to_s
      end
    end

    ##
    # Deletes an OpenStack volume
    # @param [String] disk_id volume id
    def delete_disk(disk_id)
      with_thread_name("delete_disk(#{disk_id})") do
        volume = @openstack.volumes.get(disk_id)
        state = volume.status

        cloud_error("Cannot delete volume `#{disk_id}', state is #{state}") if state.to_sym != :available

        @logger.info("Deleting volume `#{disk_id}'...")
        volume.destroy
        wait_resource(volume, :deleted, :status, true)
      end
    end

    ##
    # Attaches an OpenStack volume to an OpenStack server
    # @param [String] server_id Running OpenStack server id
    # @param [String] disk_id volume id
    def attach_disk(server_id, disk_id)
      with_thread_name("attach_disk(#{server_id}, #{disk_id})") do
        server = @openstack.servers.get(server_id)
        volume = @openstack.volumes.get(disk_id)

        device_name = attach_volume(server, volume)

        update_agent_settings(server) do |settings|
          settings["disks"] ||= {}
          settings["disks"]["persistent"] ||= {}
          settings["disks"]["persistent"][disk_id] = device_name
        end
      end
    end

    ##
    # Detaches an OpenStack volume from an OpenStack server
    # @param [String] server_id Running OpenStack server id
    # @param [String] disk_id volume id
    def detach_disk(server_id, disk_id)
      with_thread_name("detach_disk(#{server_id}, #{disk_id})") do
        server = @openstack.servers.get(server_id)
        volume = @openstack.volumes.get(disk_id)

        detach_volume(server, volume)

        update_agent_settings(server) do |settings|
          settings["disks"] ||= {}
          settings["disks"]["persistent"] ||= {}
          settings["disks"]["persistent"].delete(disk_id)
        end
      end
    end

    ##
    # Validates the deployment
    # @api not_yet_used
    def validate_deployment(old_manifest, new_manifest)
      not_implemented(:validate_deployment)
    end

    private

    ##
    # Generates initial agent settings. These settings will be read by agent
    # from OpenStack registry (also a BOSH component) on a target server. Disk
    # conventions for OpenStack are:
    # system disk: /dev/vda
    # OpenStack volumes can be configured to map to other device names later (vdc
    # through vdz, also some kernels will remap vd* to xvd*).
    #
    # @param [String] agent_id Agent id (will be picked up by agent to
    #   assume its identity
    # @param [Hash] network_spec Agent network spec
    # @param [Hash] environment
    # @return [Hash]
    def initial_agent_settings(server_name, agent_id, network_spec, environment)
      settings = {
        "vm" => {
          "name" => server_name
        },
        "agent_id" => agent_id,
        "networks" => network_spec,
        "disks" => {
          "system" => "/dev/vda",
          "ephemeral" => "/dev/vdb",
          "persistent" => {}
        }
      }

      settings["env"] = environment if environment
      settings.merge(@agent_properties)
    end

    def update_agent_settings(server)
      unless block_given?
        raise ArgumentError, "block is not provided"
      end

      # TODO uncomment to test registry
      @logger.info("Updating server settings for `#{server.id}'...")
      settings = @registry.read_settings(server.name)
      yield settings
      @registry.update_settings(server.name, settings)
    end

    def generate_unique_name
      UUIDTools::UUID.random_create.to_s
    end

    ##
    # Soft reboots an OpenStack server
    # @param [Fog::Compute::OpenStack::Server] server OpenStack server
    def soft_reboot(server)
      @logger.info("Soft rebooting server `#{server.id}'...")
      server.reboot
      wait_resource(server, :active, :state)
    end

    ##
    # Hard reboots an OpenStack server
    # @param [Fog::Compute::OpenStack::Server] server OpenStack server
    def hard_reboot(server)
      @logger.info("Hard rebooting server `#{server.id}'...")
      server.reboot(type = 'HARD')
      wait_resource(server, :active, :state)
    end

    ##
    # Attaches an OpenStack volume to an OpenStack server
    # @param [Fog::Compute::OpenStack::Server] server OpenStack server
    # @param [Fog::Compute::OpenStack::Volume] volume OpenStack volume
    def attach_volume(server, volume)
      volume_attachments = @openstack.get_server_volumes(server.id).body['volumeAttachments']
      device_names = Set.new(volume_attachments.collect! {|v| v["device"] })
      new_attachment = nil

      ("c".."z").each do |char|
        dev_name = "/dev/vd#{char}"
        if device_names.include?(dev_name)
          @logger.warn("`#{dev_name}' on `#{server.id}' is taken")
          next
        end
        @logger.info("Attaching volume `#{volume.id}' to `#{server.id}', device name is `#{dev_name}'")
        if volume.attach(server.id, dev_name)
          wait_resource(volume, :"in-use")
          new_attachment = dev_name
        end
        break
      end

      if new_attachment.nil?
        cloud_error("Server has too many disks attached")
      end

      new_attachment
    end

    ##
    # Detaches an OpenStack volume from an OpenStack server
    # @param [Fog::Compute::OpenStack::Server] server OpenStack server
    # @param [Fog::Compute::OpenStack::Volume] volume OpenStack volume
    def detach_volume(server, volume)
      volume_attachments = @openstack.get_server_volumes(server.id).body['volumeAttachments']
      device_map = volume_attachments.collect! {|v| v["volumeId"] }

      if !device_map.include?(volume.id)
        cloud_error("Disk `#{volume.id}' is not attached to server `#{server.id}'")
      end

      @logger.info("Detaching volume `#{volume.id}' from `#{server.id}'...")
      volume.detach(server.id, volume.id)
      wait_resource(volume, :available)
    end

    ##
    # Uploads a new image to OpenStack via Glance
    # @param [Hash] image_params Image params
    def upload_image(image_params)
      @logger.info("Creating new image...")
      image = @glance.images.create(image_params)

      @logger.info("Creating new image `#{image.id}'...")
      wait_resource(image, :active)

      image.id.to_s
    end

    ##
    # Reads current server id from OpenStack metadata. We are assuming
    # server id cannot change while current process is running
    # and thus memoizing it.
    def current_server_id
      @metadata_lock.synchronize do
        return @current_server_id if @current_server_id

        client = HTTPClient.new
        client.connect_timeout = METADATA_TIMEOUT
        # Using 169.254.169.254 is an OpenStack convention for getting
        # server metadata
        uri = "http://169.254.169.254/latest/user-data"

        headers = {"Accept" => "application/json"}
        response = client.get(uri, {}, headers)
        unless response.status == 200
          cloud_error("Server metadata endpoint returned HTTP #{response.status}")
        end

        user_data = Yajl::Parser.parse(response.body)
        unless user_data.is_a?(Hash)
          cloud_error("Invalid response from #{uri} , Hash expected, " \
                      "got #{response.body.class}: #{response.body}")
        end

        unless user_data.has_key?("server") &&
               user_data["server"].has_key?("name")
          cloud_error("Cannot parse user data for endpoint #{user_data.inspect}")
        end
        @current_server_id = user_data["server"]["name"]
      end

    rescue HTTPClient::TimeoutError
      cloud_error("Timed out reading server metadata, " \
                  "please make sure CPI is running on an OpenStack server")
    end

    def find_device(vd_name)
      xvd_name = vd_name.gsub(/^\/dev\/vd/, "/dev/xvd")

      DEVICE_POLL_TIMEOUT.times do
        if File.blockdev?(vd_name)
          return vd_name
        elsif File.blockdev?(xvd_name)
          return xvd_name
        end
        sleep(1)
      end

      cloud_error("Cannot find OpenStack volume on current server")
    end

    def unpack_image(tmp_dir, image_path)
      output = `tar -C #{tmp_dir} -xzf #{image_path} 2>&1`
      if $?.exitstatus != 0
        cloud_error("Failed to unpack stemcell root image" \
                    "tar exit status #{$?.exitstatus}: #{output}")
      end

      root_image = File.join(tmp_dir, "root.img")
      unless File.exists?(root_image)
        cloud_error("Root image is missing from stemcell archive")
      end
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

      unless @options.has_key?("registry") &&
          @options["registry"].is_a?(Hash) &&
          @options["registry"]["endpoint"] &&
          @options["registry"]["user"] &&
          @options["registry"]["password"]
        raise ArgumentError, "Invalid registry configuration parameters"
      end
    end

    def task_checkpoint
      Bosh::Clouds::Config.task_checkpoint
    end

  end

end
