#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet_spec/files'
require 'puppet_spec/modules'
require 'puppet/module/task'

describe Puppet::Module::Task do
  include PuppetSpec::Files

  let(:env) { mock("environment") }
  let(:modpath) { tmpdir('task_modpath') }
  let(:mymodpath) { File.join(modpath, 'mymod') }
  let(:mymod) { Puppet::Module.new('mymod', mymodpath, env) }
  let(:tasks_path) { File.join(mymodpath, 'tasks') }
  let(:tasks_glob) { File.join(mymodpath, 'tasks', '*') }

  it "cannot construct tasks with illegal names" do
    expect { Puppet::Module::Task.new(mymod, "iLegal", []) }
      .to raise_error(Puppet::Module::Task::InvalidName,
                      "Task names must start with a lowercase letter and be composed of only lowercase letters, numbers, and underscores")
  end

  it "cannot construct tasks whose files are outside of their module's tasks directory" do
    outside_file = "/var/root/secret_tasks/classified"
    expect { Puppet::Module::Task.new(mymod, "fail", [outside_file]) }
      .to raise_error(Puppet::Module::Task::InvalidFile,
                     "The file '#{outside_file}' is not located in the mymod module's tasks directory")
  end

  it "constructs tasks as expected when every task has a metadata file with the same name (besides extension)" do
    Dir.expects(:glob).with(tasks_glob).returns(%w{task1.json task1 task2.json task2.exe task3.json task3.sh})
    tasks = Puppet::Module::Task.tasks_in_module(mymod)

    expect(tasks.count).to eq(3)
    expect(tasks.map{|t| t.name}).to eq(%w{mymod::task1 mymod::task2 mymod::task3})
    expect(tasks.map{|t| t.metadata_file}).to eq(["#{tasks_path}/task1.json",
                                                  "#{tasks_path}/task2.json",
                                                  "#{tasks_path}/task3.json"])
    expect(tasks.map{|t| t.files}).to eq([["#{tasks_path}/task1"],
                                          ["#{tasks_path}/task2.exe"],
                                          ["#{tasks_path}/task3.sh"]])
  end

  it "constructs tasks as expected when some tasks don't have a metadata file" do
    Dir.expects(:glob).with(tasks_glob).returns(%w{task1 task2.exe task3.json task3.sh})
    tasks = Puppet::Module::Task.tasks_in_module(mymod)

    expect(tasks.count).to eq(3)
    expect(tasks.map{|t| t.name}).to eq(%w{mymod::task1 mymod::task2 mymod::task3})
    expect(tasks.map{|t| t.metadata_file}).to eq([nil, nil, "#{tasks_path}/task3.json"])
    expect(tasks.map{|t| t.files}).to eq([["#{tasks_path}/task1"],
                                          ["#{tasks_path}/task2.exe"],
                                          ["#{tasks_path}/task3.sh"]])
  end

  it "constructs tasks as expected when a task has multiple executable files" do
    Dir.expects(:glob).with(tasks_glob).returns(%w{task1.elf task1.exe task1.json task2.ps1 task2.sh})
    tasks = Puppet::Module::Task.tasks_in_module(mymod)

    expect(tasks.count).to eq(2)
    expect(tasks.map{|t| t.name}).to eq(%w{mymod::task1 mymod::task2})
    expect(tasks.map{|t| t.metadata_file}).to eq(["#{tasks_path}/task1.json", nil])
    expect(tasks.map{|t| t.files}).to eq([["#{tasks_path}/task1.elf", "#{tasks_path}/task1.exe"],
                                          ["#{tasks_path}/task2.ps1", "#{tasks_path}/task2.sh"]])
  end

  it "finds files whose names (besides extensions) are valid task names" do
    Dir.expects(:glob).with(tasks_glob).returns(%w{task task_1 xx_t_a_s_k_2_xx})
    tasks = Puppet::Module::Task.tasks_in_module(mymod)

    expect(tasks.count).to eq(3)
    expect(tasks.map{|t| t.name}).to eq(%w{mymod::task mymod::task_1 mymod::xx_t_a_s_k_2_xx})
  end

  it "ignores files that have names (besides extensions) that are not valid task names" do
    Dir.expects(:glob).with(tasks_glob).returns(%w{.nottask.exe .wat !runme _task 2task2furious def_a_task_PSYCH Fake_task not-a-task realtask})
    tasks = Puppet::Module::Task.tasks_in_module(mymod)

    expect(tasks.count).to eq(1)
    expect(tasks.map{|t| t.name}).to eq(%w{mymod::realtask})
  end

  it "ignores files that have names ending in .conf and .md" do
    Dir.expects(:glob).with(tasks_glob).returns(%w{ginuwine_task task.conf readme.md other_task.md})
    tasks = Puppet::Module::Task.tasks_in_module(mymod)

    expect(tasks.count).to eq(1)
    expect(tasks.map{|t| t.name}).to eq(%w{mymod::ginuwine_task})
  end

  it "gives the 'init' task a name that is just the module's name" do
    expect(Puppet::Module::Task.new(mymod, 'init', ["#{tasks_path}/init.sh"]).name).to eq('mymod')
  end
end

describe Puppet::Module::Task do
  include PuppetSpec::Files

  let(:env) { mock("environment") }
  let(:modpath) { tmpdir('task_modpath') }
  let(:mymodpath) { File.join(modpath, 'mymod') }
  let!(:mymod) { PuppetSpec::Modules.create('mymod', mymodpath, :environment => env) }
  let(:mytaskpath) { mymod.tasks_directory }
  let(:mytaskjson) { File.join(mymod.tasks_directory, 'mytask.json') }

  it "returns the expected utf-8 data when the JSON metadata file exists and is well-formed and " do
    rune_utf8 = "\u16A0\u16C7\u16BB" # ᚠᛇᚻ
    description = "Perform routine maintenance on your Viking longships, by #{rune_utf8}"
    json_metadata = <<-EOF
    {
      "description": "#{description}",
      "supportsNoop": true
    }
    EOF
    File.expects(:read).with(mytaskjson, {encoding: 'utf-8'}).returns(json_metadata)

    mytask = Puppet::Module::Task.new(mymod, 'mytask', [], mytaskjson)
    expect(mytask.metadata).to eq({'description' => description, 'supportsNoop' => true})
  end

  it "returns an empty map for the metadata when there is no metadata file" do
    mytask = Puppet::Module::Task.new(mymod, 'mytask', [], nil)
    expect(mytask.metadata).to eq({})
  end

  it "returns an empty map for the metadata when the file cannot be read" do
    File.expects(:read).with(mytaskjson, {encoding: 'utf-8'}).raises(Errno::ENOENT)

    mytask = Puppet::Module::Task.new(mymod, 'mytask', [], mytaskjson)
    expect(mytask.metadata).to eq({})
  end

  describe "when the JSON metadata file is malformed" do
    it "returns the empty map if --strict is not error" do
      Puppet[:strict] = :warning
      Puppet.expects(:warning)
      File.expects(:read).with(mytaskjson, {encoding: 'utf-8'}).returns('{ "leave u hanging"')

      mytask = Puppet::Module::Task.new(mymod, 'mytask', [], mytaskjson)
      expect(mytask.metadata).to eq({})
    end

    it "throws an error if --strict is error" do
      Puppet[:strict] = :error
      File.expects(:read).with(mytaskjson, {encoding: 'utf-8'}).returns('{ "leave u hanging"')
      mytask = Puppet::Module::Task.new(mymod, 'mytask', [], mytaskjson)
      expect { mytask.metadata }.to raise_error(Puppet::Module::FaultyMetadata)
    end
  end

  it "does not read the metadata file when the task is created" do
    Puppet::Module::Task.any_instance.expects(:read_metadata).never
    File.expects(:read).with(mytaskjson, {encoding: 'utf-8'}).never

    mytask = Puppet::Module::Task.new(mymod, 'mytask', [], mytaskjson)
  end

  it "only reads the metadata file once" do
    File.expects(:read).with(mytaskjson, {encoding: 'utf-8'}).once.returns('{}')

    mytask = Puppet::Module::Task.new(mymod, 'mytask', [], mytaskjson)
    mytask.metadata
    mytask.metadata
  end
end
