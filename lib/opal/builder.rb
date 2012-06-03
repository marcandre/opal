require 'fileutils'

module Opal
  class Builder
    def self.runtime
      core_dir   = Opal.core_dir
      load_order = File.join core_dir, 'load_order'
      result     = []
      corelib    = File.read(load_order).strip.split.map do |c|
        File.read File.join(core_dir, "#{c}.rb")
      end

      methods = Parser::METHOD_NAMES.map { |f, t| "'#{f}': '$#{t}$'" }
      runtime = File.read(File.join core_dir, 'runtime.js')
      corelib = Opal.parse corelib.join("\n")

      [
        "/*!",
        " * Opal v#{Opal::VERSION}",
        " * http://opalrb.org",
        " *",
        " * Copyright 2012, Adam Beynon",
        " * Released under the MIT License",
        " */",
        "(function(undefined) {",
        runtime,
        "var method_names = {#{ methods.join ', ' }},",
        "reverse_method_names = {};",
        "for (var id in method_names) {",
        "reverse_method_names[method_names[id]] = id;",
        "}",
        corelib,
        "}).call(this);"
      ].join("\n")
    end

    def self.build(opts)
      self.new(opts).build
    end

    def initialize(options = {})
      @sources = Array(options[:files])
      @options = options
      @debug   = !!options[:debug]
    end

    def build
      unless out = @options[:out]
        out = "out.js"
      end

      @dir = File.expand_path(@options[:dir] || Dir.getwd)

      files = files_for @sources
      FileUtils.mkdir_p File.dirname(out)

      build_to files, out
    end

    def files_for(sources)
      files = []

      sources.each do |s|
        s = File.join @dir, s
        if File.directory? s
          files.push *Dir[File.join s, '**/*.{rb,js}']
        elsif File.extname(s) == '.rb' or File.extname(s) == ".js"
          files << s
        end
      end

      files.map! { |f| File.expand_path f }

      files
    end

    def build_to(files, out)
      @parser = Parser.new :debug => @debug

      files.each { |file| build_file(file) }

      File.open(out, 'w+') do |o|
        files.each do |file|
          js = build_file file
          o.puts js
        end
      end
    end

    def build_file(file)
      lib_name = lib_name_for file

      code = if File.extname(file) == '.rb'
        @parser.parse File.read(file), file
      else
        File.read file
      end

      "Opal.define(#{lib_name.inspect}, #{code});"
    end

    def lib_name_for(file)
      file = file.sub /^#{@dir}\//, ''
      file = file.chomp File.extname(file)
      file.sub /^lib\/(opal\/)?/, ''
    end
  end
end