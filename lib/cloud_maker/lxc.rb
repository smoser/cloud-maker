module CloudMaker
  def foo()
    puts "HELLO"
  end

  class LXC
    # Internal: info to get the archiver
    attr_accessor :archiver_info
    # Internal: the data directory for reading/writing
    attr_accessor :data_dir

    # Public: A CloudMaker::Config hash that describes the config properties EC2 relies on.
    CLOUD_MAKER_CONFIG = {
      'cloud-maker' => {
        'container_name' => {
          'required' => true,
          'description' => "The name of the lxc source container (see lxc-ls)"
        },
        'ephemeral' => {
          'required' => false,
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
      required_keys = [:archiver_info]
      unless (required_keys - options.keys).empty?
        raise RuntimeError.new("Instantiated #{self.class} without required attributes: #{required_keys - options.keys}.")
      end
      if not system('which lxc-cloud')
        raise RuntimeError.new("No lxc-cloud.  Install it?")
      end
      self.archiver_info = options[:archiver_info]
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
        :key_name => cloud_maker_config['key_pair'],
        :user_data => user_data
      }

      # FIXME: use a temp file
      user_data_file = "/tmp/temp-user-data"
      fp = open(user_data_file,"w")
      fp.write(user_data)
      fp.close()

      cmd = "lxc-cloud start"
      if cloud_maker_config['key_pair']
        cmd += " --key=" + cloud_maker_config['key_pair']
      end
      cmd += " --user-data-file=\"#{user_data_file}\""
      cmd += " #{cloud_maker_config['container_name']}"

      start_time = Time.now.to_i
      puts cmd
      output = `#{cmd}`
      (instance_id, state, ip) = output.split("\t")
      File.unlink(user_data_file)

      instance = {
        :instance_id => instance_id,
        :start => start_time,
        :path => cloud_maker_config["tags"][PATH_TAG],
        :ip_address => ip,
        :key_name => cloud_maker_config['key_pair'],
        :container_name => cloud_maker_config['container_name'],
        :tags => cloud_maker_config["tags"]
      }
      
      # dump yaml to self.data_dir/instance-id.yaml
      fp = File.open([self.data_dir, instance[:instance_id] + ".yaml"].join("/"), "w")
      fp.write(YAML::dump(instance))

      archiver = LocalArchiver.new(
        :instance_id => instance[:instance_id],
        :path => instance[:path],
      )
      archiver.store_archive(cloud_maker_config, instance)

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

    class << self
      # Public: Generates a hash of properties from an AWS::EC2 instance
      #
      # Returns a hash of properties for the instance.
      def instance_to_hash(instance)
        instance
      end
    end
  end

end

# vi: ts=2 expandtab
