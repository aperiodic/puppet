#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet_spec/files'
require 'puppet_spec/modules'
require 'puppet/module/task'

describe Puppet::Module::Task do
  include PuppetSpec::Files

  let!(:modpath) do
    tmpdir('task_modpath')
  end

  let!(:mymodpath) { File.join(modpath, 'mymod') }
  let(:mymod) { Puppet::Module.new('mymod', mymodpath, nil) }
  let(:tasks_path) { File.join(mymodpath, 'tasks') }
  let(:tasks_glob) { File.join(mymodpath, 'tasks', '*') }

  it "cannot construct tasks with illegal names" do
    expect { Puppet::Module::Task.new(mymod, "iLegal", []) }
      .to raise_error(Puppet::Module::Task::InvalidName,
                      "Task names must match the pattern /^[a-z][a-z0-9_]*$/")
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
    expect(tasks.map{|t| t.name}).to eq(%w{task1 task2 task3})
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
    expect(tasks.map{|t| t.name}).to eq(%w{task1 task2 task3})
    expect(tasks.map{|t| t.metadata_file}).to eq([nil, nil, "#{tasks_path}/task3.json"])
    expect(tasks.map{|t| t.files}).to eq([["#{tasks_path}/task1"],
                                          ["#{tasks_path}/task2.exe"],
                                          ["#{tasks_path}/task3.sh"]])
  end

  it "constructs tasks as expected when a task has multiple executable files" do
    Dir.expects(:glob).with(tasks_glob).returns(%w{task1.elf task1.exe task1.json task2.ps1 task2.sh})
    tasks = Puppet::Module::Task.tasks_in_module(mymod)

    expect(tasks.count).to eq(2)
    expect(tasks.map{|t| t.name}).to eq(%w{task1 task2})
    expect(tasks.map{|t| t.metadata_file}).to eq(["#{tasks_path}/task1.json", nil])
    expect(tasks.map{|t| t.files}).to eq([["#{tasks_path}/task1.elf", "#{tasks_path}/task1.exe"],
                                          ["#{tasks_path}/task2.ps1", "#{tasks_path}/task2.sh"]])
  end

  it "finds files whose names (besides extensions) are valid task names" do
    Dir.expects(:glob).with(tasks_glob).returns(%w{task task_1 xx_t_a_s_k_2_xx})
    tasks = Puppet::Module::Task.tasks_in_module(mymod)

    expect(tasks.count).to eq(3)
    expect(tasks.map{|t| t.name}).to eq(%w{task task_1 xx_t_a_s_k_2_xx})
  end

  it "ignores files that have names (besides extension) that are not valid task names" do
    Dir.expects(:glob).with(tasks_glob).returns(%w{.nottask.exe .wat !runme _task 2task2furious def_a_task_PSYCH Fake_task not-a-task realtask})
    tasks = Puppet::Module::Task.tasks_in_module(mymod)

    expect(tasks.count).to eq(1)
    expect(tasks.map{|t| t.name}).to eq(%w{realtask})
  end

  it "ignores files that have names ending in .conf and .md" do
    Dir.expects(:glob).with(tasks_glob).returns(%w{ginuwine_task task.conf readme.md other_task.md})
    tasks = Puppet::Module::Task.tasks_in_module(mymod)

    expect(tasks.count).to eq(1)
    expect(tasks.map{|t| t.name}).to eq(%w{ginuwine_task})
  end
end
