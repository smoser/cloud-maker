module CloudMaker
  class S3Archiver < CloudMaker::Archiver

    # Public: Gets/Sets the AWS access key.
    attr_accessor :aws_secret_access_key
    # Public: Gets/Sets the AWS secret.
    attr_accessor :aws_access_key_id

    # Public: Creates a new S3 Archiver instance
    #
    # options - S3 configuration options
    #           :aws_access_key_id     - (required) The AWS access key
    #           :aws_secret_access_key - (required) The AWS secret
    #           :path                  - (required) The path [bucket/path] for the archiver to access
    #           :instance_id           - (required) The AWS instance ID the archive describes
    #
    # Returns a new CloudMaker::S3Archiver instance
    # Raises RuntimeError if any of the required options are not specified
    def initialize(options)
      required_keys = [:aws_access_key_id, :aws_secret_access_key, :instance_id, :path]
      unless (required_keys - options.keys).empty?
        raise RuntimeError.new("Instantiated #{self.class} without required attributes: #{required_keys - options.keys}.")
      end

      self.instance_id = options[:instance_id]
      self.aws_access_key_id = options[:aws_access_key_id]
      self.aws_secret_access_key = options[:aws_secret_access_key]

      # normalize the path
      toks = normpath(options[:path]).split("/",2)
      if toks.size == 2
        self.prefix = toks[1]
      else
        self.prefix = ""
      end

      self.bucketname = toks[0]

      self.bucket = AWS::S3.new(
        :access_key_id => self.aws_access_key_id,
        :secret_access_key => self.aws_secret_access_key
      ).buckets[self.bucketname]

      raise RuntimeError.new("The S3 bucket #{self.bucketname} does not exist.") unless self.bucket.exists?
    end

    # Internal store a key (filename)
    def write_key(key, value)
      self.bucket.objects.create(key, value)
    end

    def read_key(key)
        self.bucket.objects[key].read
    end

  end
end

# internal
def normpath(input)
  toks = []
  input.split("/").each do |tok|
    if tok != ""
      toks.push(tok)
    end
  end
  toks.join("/")
end

# vi: ts=2 expandtab
