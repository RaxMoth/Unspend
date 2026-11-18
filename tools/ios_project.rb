#!/usr/bin/env ruby
# frozen_string_literal: true

# Applies Unspend's Xcode project settings that are tedious to keep right by hand.
# Idempotent: running it twice produces no further change.
#
#   cd ios && LANG=en_US.UTF-8 bundle exec ruby ../tools/ios_project.rb
#
# What it does:
#   1. iPhone only (TARGETED_DEVICE_FAMILY = 1) on the project and every target.
#   2. The three app extensions take their version and build number from Flutter
#      (Flutter/Extension.xcconfig), so they always match the Runner app.
#   3. FocusMonitor gets a Resources phase containing its privacy manifest.
#   4. Swift files under ios/Shared are compiled into the targets that use them.
#   5. Every Swift file in ios/Runner is a member of the Runner target.

require 'xcodeproj'

IOS_DIR = File.expand_path('../ios', __dir__)
PROJECT_PATH = File.join(IOS_DIR, 'Runner.xcodeproj')

EXTENSION_TARGETS = %w[FocusMonitor AppBlocker ShieldConfigurationExtension].freeze

# Foundation-only rule engine: every target that reads the App Group needs it.
SHIELD_CORE_TARGETS = %w[Runner FocusMonitor ShieldConfigurationExtension].freeze
# Uses ManagedSettings / FamilyControls: only the targets that apply shields.
ENFORCER_TARGETS = %w[Runner FocusMonitor].freeze

project = Xcodeproj::Project.open(PROJECT_PATH)
targets = project.targets.to_h { |t| [t.name, t] }

def find_or_add_reference(group, relative_path, name: nil)
  existing = group.files.find { |f| f.path == relative_path }
  return existing if existing

  ref = group.new_reference(relative_path)
  ref.name = name if name
  ref
end

def find_or_add_group(parent, name, path)
  parent.groups.find { |g| g.display_name == name } || parent.new_group(name, path)
end

def add_to_sources(target, ref)
  phase = target.source_build_phase
  return if phase.files_references.include?(ref)

  phase.add_file_reference(ref)
end

# ── 1. iPhone only ───────────────────────────────────────────────────────────
project.build_configurations.each do |config|
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1'
end
project.targets.each do |target|
  target.build_configurations.each do |config|
    next unless config.build_settings.key?('TARGETED_DEVICE_FAMILY')

    config.build_settings['TARGETED_DEVICE_FAMILY'] = '1'
  end
end

# ── 2. Extension versions follow the Flutter build ───────────────────────────
flutter_group = project.main_group.groups.find { |g| g.display_name == 'Flutter' }
raise 'Flutter group not found in the Xcode project' unless flutter_group

extension_xcconfig = find_or_add_reference(
  flutter_group, 'Flutter/Extension.xcconfig', name: 'Extension.xcconfig'
)

EXTENSION_TARGETS.each do |name|
  target = targets.fetch(name)
  target.build_configurations.each do |config|
    config.base_configuration_reference = extension_xcconfig
    config.build_settings['MARKETING_VERSION'] = '$(FLUTTER_BUILD_NAME)'
    config.build_settings['CURRENT_PROJECT_VERSION'] = '$(FLUTTER_BUILD_NUMBER)'
  end
end

# ── 3. FocusMonitor privacy manifest ─────────────────────────────────────────
focus_monitor = targets.fetch('FocusMonitor')
focus_group = project.main_group.groups.find { |g| g.display_name == 'FocusMonitor' }
raise 'FocusMonitor group not found in the Xcode project' unless focus_group

if File.exist?(File.join(IOS_DIR, 'FocusMonitor', 'PrivacyInfo.xcprivacy'))
  manifest = find_or_add_reference(focus_group, 'PrivacyInfo.xcprivacy')
  resources = focus_monitor.resources_build_phase
  resources.add_file_reference(manifest) unless resources.files_references.include?(manifest)
end

# ── 4. Shared Swift sources ──────────────────────────────────────────────────
shared_dir = File.join(IOS_DIR, 'Shared')
if Dir.exist?(shared_dir)
  shared_group = find_or_add_group(project.main_group, 'Shared', 'Shared')
  core_group = find_or_add_group(shared_group, 'ShieldCore', 'Sources/ShieldCore')

  Dir.glob(File.join(shared_dir, 'Sources', 'ShieldCore', '*.swift')).sort.each do |file|
    ref = find_or_add_reference(core_group, File.basename(file))
    SHIELD_CORE_TARGETS.each { |name| add_to_sources(targets.fetch(name), ref) }
  end

  # Package.swift is the SwiftPM manifest used by `swift test`; it must never
  # be compiled into an app target.
  shared_group.files.select { |f| f.path == 'Package.swift' }.each do |stale|
    project.targets.each { |t| t.source_build_phase.remove_file_reference(stale) }
    stale.remove_from_project
  end

  Dir.glob(File.join(shared_dir, '*.swift')).sort.each do |file|
    next if File.basename(file) == 'Package.swift'

    ref = find_or_add_reference(shared_group, File.basename(file))
    ENFORCER_TARGETS.each { |name| add_to_sources(targets.fetch(name), ref) }
  end
end

# ── 5. Runner sources ────────────────────────────────────────────────────────
# A Swift file added to ios/Runner by hand or by a tool is not compiled until
# it is a member of the target; pick up any that are missing.
runner = targets.fetch('Runner')
runner_group = project.main_group.groups.find { |g| g.display_name == 'Runner' }
raise 'Runner group not found in the Xcode project' unless runner_group

Dir.glob(File.join(IOS_DIR, 'Runner', '*.swift')).sort.each do |file|
  ref = find_or_add_reference(runner_group, File.basename(file))
  add_to_sources(runner, ref)
end

project.save
puts "Updated #{PROJECT_PATH}"
