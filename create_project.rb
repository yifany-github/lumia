require 'xcodeproj'

project_path = 'iOS/Lumina/Lumina.xcodeproj'
project = Xcodeproj::Project.new(project_path)

# Create a target for the app
target = project.new_target(:application, 'Lumina', :ios, '16.0')

# Configure build settings
target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.example.Lumina'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  config.build_settings['INFOPLIST_FILE'] = 'Lumina/Info.plist'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings.delete('DEVELOPMENT_ASSET_PATHS')
end

# Find or create the main group
group = project.main_group.find_subpath('Lumina', true)
group.set_source_tree('<group>')
group.set_path('Lumina')

# Function to recursively add files
def add_files_to_target(project, target, group, dir_path)
  Dir.foreach(dir_path) do |entry|
    next if entry == '.' or entry == '..'
    
    full_path = File.join(dir_path, entry)
    if File.directory?(full_path)
      sub_group = group.new_group(entry, entry)
      add_files_to_target(project, target, sub_group, full_path)
    elsif full_path.end_with?('.swift', '.xcassets', '.plist')
      file_ref = group.new_file(entry)
      if entry != 'Info.plist'
        target.add_file_references([file_ref])
      end
    end
  end
end

add_files_to_target(project, target, group, 'iOS/Lumina/Lumina')

project.save
