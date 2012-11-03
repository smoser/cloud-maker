module CloudMaker
  class LXC
    # Public: A CloudMaker::Config hash that describes the config properties EC2 relies on.
    CLOUD_MAKER_CONFIG = {
      'cloud-maker' => {
        'container_name' => {
          'required' => true,
          'description' => "The name of the lxc container (see lxc-ls)"
        },
        'ephemeral' => {
          'required' => true,
          'default' => true
        },
      }
    }

    DATA_DIR = File.expand_path("~/.cloud-maker")

    # Public: The name of the tag that will be used to find the name of an s3 bucket for archiving/information retrieval
    PATH_TAG = 'archive_bucket'

    # Public: Creates a new EC2 instance
    #
    # cloud_maker_config - A CloudMaker::Config object describing the instance
    #                      to be managed.
    #
    # Returns a new CloudMaker::LXC instance
    # Raises RuntimeError if any of the required options are not specified
    def initialize(options)
      if not system('which lxc-create-ephemeral')
        raise RuntimeError.new("No lxc-create-ephemeral command.  Install lxc?")
      end
      self.data_dir = [DATA_DIR, "lxc"].join("/") # FIXME: os.sep?
      FileUtils.mkdir_p(self.data_dir)
    end

    # Public: Fetch archived information about an instance
    #
    # Returns a hash of information about the instance as it was launched
    def info(instance_id)
      instance = find_instance(instance_id)
      path = instance.tags[PATH_TAG]

      archiver = Archiver.archive_factory(self.archiver_info, instance_id, path)
      archiver.load_archive
    end

    # Public: Terminates the specified EC2 instance.
    #
    # Returns nothing.
    def terminate(instance_id)
      find_instance(instance_id).terminate
    end

    # Public: Launches a new EC2 instance, associates any specified elastic IPS
    # with it, adds any specified tags, and archives the launch details to S3.
    #
    # Returns an AWS::EC2 object for the launched instance.
    def launch(cloud_maker_config)
      user_data = cloud_maker_config.to_user_data

      config = {
        :container_name => cloud_maker_config['container_name'],
        :ephemeral => cloud_maker_config['ephemeral'],
        :user_data => user_data
      }

      # generate instance-id, record start time
      inst_id = sprintf("i-%08d", (100000 + rand(10**8)).to_s)
      start = Time.now.to_i

      # [lxc change] add '--callback' to 'lxc-start-ephemeral'
      # create CALLBACK file (temp file) that will
      #   populate /var/lib/cloud/data/seed
      #    includes instance-id as called above and user-data
      # lxc-start-ephemeral --name container_name --callback $TEMP_D/callback
      # store some info in the instance yaml
      #   * timestamp
      #   * pid of lxc process
      #   * somehow wait for ip address, get ip address

      # tags is required
      lxc_create(config, cloud_maker_config['tags'])

      # dump yaml to self.data_dir/instance-id.yaml
      # HERE: TODO
      File.open([self.data_dir, instance['instance-id']].join("/"))

      archiver = LocalArchiver.new(
        :instance_id => instance.id,
        :path => cloud_maker_config["tags"][BUCKET_TAG]
      )
      archiver.store_archive(cloud_maker_config, self.class.instance_to_hash(instance))

      instance
    end

    # Internal: Find the instance object for an instance ID regardless of what
    # region the instance is in. It looks in the default region (us-east-1) first
    # and then looks in all regions if it's not there.
    #
    # Returns nil or an AWS::EC2::Instance
    def find_instance(instance_id)
      # Check the default region first
      return ec2.instances[instance_id] if ec2.instances[instance_id].exists?

      # If we don't find it there look in every region
      instance = nil
      ec2.regions.each do |region|
        if region.instances[instance_id].exists?
          instance = region.instances[instance_id]
          break
        end
      end

      instance
    end


    # Internal: Find the region object for a given availability zone. Currently works
    # based on amazon naming conventions and will break if they change.
    #
    # Returns an AWS::EC2::Region
    # Raises a RuntimeError if the region doesn't exist
    def find_region(availability_zone)
      region_name = availability_zone.gsub(/(\d)\w$/, '\1')
      if ec2.regions[region_name].exists?
        ec2.regions[region_name]
      else
        raise RuntimeError.new("The region #{region_name} doesn't exist - region name generated from availability_zone: #{availability_zone}.")
      end
    end

#    protected
#      # Protected: get an Archiver object for a given instance
#      def get_archiver(instance, cloud_maker_config=None)
#        LocalArchiver.new(
#          :instance_id => instance.id,
#          :path => cloud_maker_config["tags"][BUCKET_TAG]
#        )
#      end

    class << self
      # Public: Generates a hash of properties from an AWS::EC2 instance
      #
      # Returns a hash of properties for the instance.
      def instance_to_hash(instance)
        {
          :instance_id => instance.id,
          :ami => instance.image_id,
          :api_termination_disabled => instance.api_termination_disabled?,
          :dns_name => instance.dns_name,
          :ip_address => instance.ip_address,
          :private_ip_address => instance.private_ip_address,
          :key_name => instance.key_name,
          :owner_id => instance.owner_id,
          :status => instance.status,
          :tags => instance.tags.inject({}) {|hash, tag| hash[tag.first] = tag.last;hash}
        }
      end
    end

  end

  def lxc_start(config, cloud_maker_config)
    # start an instance (lxc-start-ephemeral)
  end

  def lxc_destroy(instance_id,ucontainer_name)
  end


end

# vi: ts=2 expandtab
