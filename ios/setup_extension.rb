#!/usr/bin/env ruby
# Run this script on macOS to add PacketTunnel target to the Xcode project.
# Usage: cd ios && ruby setup_extension.rb
#
# This script uses xcodeproj gem to programmatically add the Network Extension target.
# Install: gem install xcodeproj

require 'xcodeproj'

project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Check if PacketTunnel target already exists
if project.targets.any? { |t| t.name == 'PacketTunnel' }
  puts "PacketTunnel target already exists, skipping..."
  exit 0
end

puts "Adding PacketTunnel target..."

# Create the extension target
extension_target = project.new_target(
  :app_extension,
  'PacketTunnel',
  :ios,
  '15.0'
)

# Set bundle identifier
extension_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.papaha.vpn.PacketTunnel'
  config.build_settings['INFOPLIST_FILE'] = 'PacketTunnel/Info.plist'
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'PacketTunnel/PacketTunnel.entitlements'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['CURRENT_PROJECT_VERSION'] = '1'
  config.build_settings['MARKETING_VERSION'] = '2.0.0'
end

# Add Swift source file
group = project.new_group('PacketTunnel', 'PacketTunnel')
swift_ref = group.new_file('PacketTunnel/PacketTunnelProvider.swift')
extension_target.add_file_references([swift_ref])

# Add Info.plist reference
group.new_file('PacketTunnel/Info.plist')

# Add entitlements reference
group.new_file('PacketTunnel/PacketTunnel.entitlements')

# Add LibXray.xcframework if it exists (precompiled, no Go build needed)
libxray_path = 'Frameworks/LibXray.xcframework'
if File.exist?(libxray_path)
  # Add as precompiled framework - no source compilation
  framework_ref = project.frameworks_group.new_file(libxray_path, :project)
  
  # Link to PacketTunnel target
  extension_target.frameworks_build_phase.add_file_reference(framework_ref)
  
  # Embed framework in extension
  embed_phase = extension_target.new_copy_files_build_phase('Embed Frameworks')
  embed_phase.dst_subfolder_spec = '10' # Frameworks
  build_file = embed_phase.add_file_reference(framework_ref)
  build_file.settings = { 'ATTRIBUTES' => ['CodeSignOnCopy', 'RemoveHeadersOnCopy'] }
  
  # Set framework search paths
  extension_target.build_configurations.each do |config|
    config.build_settings['FRAMEWORK_SEARCH_PATHS'] ||= ['$(inherited)']
    config.build_settings['FRAMEWORK_SEARCH_PATHS'] << '$(PROJECT_DIR)/Frameworks'
  end
  
  puts "LibXray.xcframework linked and embedded as precompiled framework."
else
  puts "WARNING: LibXray.xcframework not found at #{libxray_path}."
  puts "  iOS VPN will build but PacketTunnel won't have Xray-core."
  puts "  To add it later: place LibXray.xcframework in ios/Frameworks/"
end

# Add dependency: Runner depends on PacketTunnel
runner_target = project.targets.find { |t| t.name == 'Runner' }
runner_target.add_dependency(extension_target)

# Embed extension in Runner
embed_extensions_phase = runner_target.new_copy_files_build_phase('Embed App Extensions')
embed_extensions_phase.dst_subfolder_spec = '13' # PlugIns
embed_extensions_phase.add_file_reference(extension_target.product_reference)

# Add Runner entitlements
runner_target.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end

# Save
project.save

puts "Done! PacketTunnel target added successfully."
puts ""
puts "Next steps:"
puts "1. Place LibXray.xcframework in ios/ directory"
puts "2. Run: cd ios && pod install"
puts "3. Open Runner.xcworkspace in Xcode"
puts "4. Set your Team ID for both targets"
puts "5. Build and run"
