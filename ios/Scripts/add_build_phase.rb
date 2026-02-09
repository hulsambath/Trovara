#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'ios/Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'Runner' }
phase_name = 'Process Info.plist with Dart Defines'

# Check if phase already exists by safer iteration
existing_phase = target.build_phases.find do |p|
  p.respond_to?(:name) && p.name == phase_name
end

if existing_phase
  puts "Build phase '#{phase_name}' already exists."
  # Update script content just in case
  existing_phase.shell_script = '"${SRCROOT}/Scripts/process_infoplist.sh"'
  existing_phase.shell_path = '/bin/sh'
else
  puts "Adding build phase '#{phase_name}'..."
  phase = project.new(Xcodeproj::Project::Object::PBXShellScriptBuildPhase)
  phase.name = phase_name
  phase.shell_script = '"${SRCROOT}/Scripts/process_infoplist.sh"'
  phase.shell_path = '/bin/sh'

  # Find 'Thin Binary' phase index to insert after
  thin_binary_index = target.build_phases.index do |p|
    p.respond_to?(:name) && p.name == 'Thin Binary'
  end

  if thin_binary_index
    target.build_phases.insert(thin_binary_index + 1, phase)
  else
    # Insert at the end if 'Thin Binary' not found (unlikely for Flutter)
    target.build_phases << phase
  end
end

project.save
puts "Project saved."
