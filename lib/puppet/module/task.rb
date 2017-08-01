require 'puppet/util/logging'
require 'json'

class Puppet::Module::Task
  class Error < Puppet::Error; end
  class InvalidName < Error; end
  class InvalidFile < Error; end

  include Puppet::Util::Logging

  FORBIDDEN_EXTENSIONS = %w{.conf .md}
  TASK_NAME_REGEX = /^[a-z][a-z0-9_]*$/

  attr_reader :name, :module, :metadata_file, :files

  def self.is_task_name?(name)
    return true if name =~ TASK_NAME_REGEX
    return false
  end

  # Determine whether the name of a file is legal for either a task's executable or metadata file.
  def self.is_tasks_filename?(path)
    name_less_extension = File.basename(path, '.*')
    return false if not is_task_name?(name_less_extension)
    FORBIDDEN_EXTENSIONS.each do |ext|
      return false if path.end_with?(ext)
    end
    return true
  end

  def self.is_tasks_metadata_filename?(name)
    is_tasks_filename?(name) && name.end_with?('.json')
  end

  def self.is_tasks_executable_filename?(name)
    is_tasks_filename?(name) && !name.end_with?('.json')
  end

  def self.tasks_in_module(pup_module)
    Dir.glob(File.join(pup_module.tasks_directory, '*'))
       .keep_if { |f| is_tasks_filename?(f) }
       .group_by { |f| task_name_from_path(f) }
       .map { |task, files| new_with_files(pup_module, task, files) }
  end

  def initialize(pup_module, name, files, metadata_file = nil)
    if !Puppet::Module::Task.is_task_name?(name)
      raise InvalidName, "Task names must match the pattern #{TASK_NAME_REGEX.inspect}"
    end

    all_files = metadata_file.nil? ? files : files + [metadata_file]
    all_files.each do |f|
      if !f.start_with?(pup_module.tasks_directory)
        raise InvalidFile, "The file '#{f.to_s}' is not located in the #{pup_module.name} module's tasks directory"
      end
    end

    @module = pup_module
    @name = name
    @metadata_file = metadata_file if metadata_file
    @files = files
  end

  private

  def self.new_with_files(pup_module, name, tasks_files)
    files = tasks_files.map do |filename|
      File.join(pup_module.tasks_directory, File.basename(filename))
    end

    metadata_files, exe_files = files.partition { |f| is_tasks_metadata_filename?(f) }
    Puppet::Module::Task.new(pup_module, name, exe_files, metadata_files.first)
  end

  def self.task_name_from_path(path)
    return File.basename(path, '.*')
  end
end
