module PuppetSpec::Tasks
  DEFAULT_TEST_METADATA = { 'description' => 'A fake task used for testing',
                            'spec_version' => '1.0.0',
                            'supports_noop' => false,
                            'input' => %w{stdin environment},
                            'input_format' => 'json',
                            'output_format' => 'plaintext',
                            'additional_parameters' => true,
                            'required_parameters' => [],
                            'parameters' => {},
                            'output' => 'A test message',
  }

  class << self
    def create(name, pup_module, metadata_overrides = {})
      FileUtils.mkdir_p(pup_module.tasks)

      if not metadata_overrides.nil?
        metadata = DEFAULT_TEST_METADATA.merge(metadata_overrides)
        File.open(File.join(pup_module.tasks, "#{name}.json"), 'w') do |f|
          f.write(metadata.to_json)
        end
      end

      exe_path = File.join(pup_module.tasks, metadata['default_file'] || name)
      FileUtils.touch(exe_path)

    end
  end
end
