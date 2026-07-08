#
#  Podfile
#  Status
#
#  Created by Pierluigi Galdi on 18/01/2020.
#  Copyright © 2020 Pierluigi Galdi. All rights reserved.
# 

target 'Status' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for Status
  pod 'PockKit'

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings["MACOSX_DEPLOYMENT_TARGET"] = "10.13"
      config.build_settings.each do |key, value|
        if value.is_a?(String)
          config.build_settings[key] = value.gsub("DT_TOOLCHAIN_DIR", "TOOLCHAIN_DIR")
        elsif value.is_a?(Array)
          config.build_settings[key] = value.map { |item| item.is_a?(String) ? item.gsub("DT_TOOLCHAIN_DIR", "TOOLCHAIN_DIR") : item }
        end
      end
    end
  end

  Dir.glob(File.join(installer.sandbox.root, "Target Support Files", "**", "*.{xcconfig,sh}")) do |path|
    contents = File.read(path)
    updated = contents.gsub("DT_TOOLCHAIN_DIR", "TOOLCHAIN_DIR")
    File.write(path, updated) if updated != contents
  end
end

