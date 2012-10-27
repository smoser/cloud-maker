module CloudMaker
  class LocalArchiver < Archiver

    # Internal store a key (filename)
    def write_key(key, value)
      file = [self.path, key].join("/")
      FileUtils.mkdir_p(File.dirname(file))
      File.open(file, "w").write(value)
    end

    # Internal read a key
    def read_key(key)
      File.open([self.path, key].join("/"), "r").read
    end

  end
end

# vi: ts=2 expandtab
