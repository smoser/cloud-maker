module CloudMaker
  class Archiver

    # Internal: Gets/Sets the path for storing/loading archives.
    attr_accessor :path
    # Public: Gets/Sets the EC2 instance ID string.
    attr_accessor :instance_id

    # Public: All archive keys will be prefixed with KEY_PREFIX/
    KEY_PREFIX = "cloud-maker"

    INSTANCE_YAML = 'instance.yaml'
    CLOUD_CONFIG_YAML = 'cloud_config.yaml'

    # Public: Creates a new Local Archiver instance
    #
    # options - configuration options
    #           :path                  - (required) The path for top level directory
    #           :instance_id           - (required) The AWS instance ID the archive describes
    #
    # Returns a new CloudMaker::S3Archiver instance
    # Raises RuntimeError if any of the required options are not specified
    def initialize(options)
      required_keys = [:instance_id, :path]
      unless (required_keys - options.keys).empty?
        raise RuntimeError.new("Instantiated #{self.class} without required attributes: #{required_keys - options.keys}.")
      end

      self.instance_id = options[:instance_id]
      self.path = options[:path]
    end

    # Public: Generates an archive with all information relevant to an instance
    # launch and stores it to Archive
    #
    # cloud_maker_config - The CloudMaker::Config the instance was launched with
    # properties         - A Hash describing the properties of the launched instance
    #
    # Returns nothing.
    def store_archive(cloud_maker_config, properties)
      userdata = cloud_maker_config.to_user_data
      self.write_key(self.user_data_key, userdata)
      self.write_key(self.instance_yaml_key, properties.to_yaml)
      self.write_key(self.cloud_config_yaml_key, cloud_maker_config.to_hash.to_yaml)
      true
    end

    # Public: Retrieves a previously created archive from S3
    #
    # Returns the content of the archive.
    def load_archive
      {
        :user_data => self.read_key(self.user_data_key),
        :cloud_config => YAML::load(self.read_key(self.cloud_config_yaml_key)),
        :instance => YAML::load(self.read_key(self.instance_yaml_key))
      }
    end

    # Internal: Returns the key for the user_data file
    def user_data_key
      self.prefix_key('user_data')
    end

    # Internal: Returns the key for the instance yaml file
    def instance_yaml_key
      self.prefix_key('instance.yaml')
    end

    # Internal: Returns the key for the cloud config yaml file
    def cloud_config_yaml_key
      self.prefix_key('cloud_config.yaml')
    end

		# Internal store a key (filename)
		def write_key(key, value)
      raise RuntimeError.new("write_key not implemented!")
    end

		# Internal read a key
		def read_key(key)
      raise RuntimeError.new("read_key not implemented!")
    end

    # Public: Returns the key that the archive will be stored under
    def prefix_key(key)
      if self.instance_id
        [self.path, self.instance_id, key].join('/')
      else
        raise RuntimeError.new("Attempted to generate a key name without an instance id.")
      end
    end
  end
end

def archive_factory(options, instance_id, path)
	type = "ec2"
	if options.has_key?("type")
		type = options["type"]
	end

  archclass = S3Archiver
	if type == "local"
		archclass = LocalArchiver
	end
	# FIXME: how to copy ?
  options[:instance_id] = instance_id
  options[:path] = path
  archclass.new(options)
end

# vi: ts=2 noexpandtab
