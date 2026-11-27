platform :ios, '15.0'

ENV['SWIFT_VERSION'] = '5'

project 'CYLDeallocBlockExecutor.xcodeproj'

# Example app only (instructions.md, "Example demo: sectioned lists use the ClassifyMenu tag list"). The library's
# podspec and Package.swift never depend on the menu or on CYLTabBarController: they reach this library the other way
# round (CYLTabBarController depends on CYLDeallocBlockExecutor ~> 1.4), so a dependency in the library would be a cycle.
#
# One copy of this library: CYLTabBarController/Core asks for CYLDeallocBlockExecutor ~> 1.4, and the `:path` line
# below resolves it to this checkout (version 1.4.0). The Example target therefore does not compile the library
# sources itself; it imports the pod's module.
#
# CYLTabBarController is read-only here (another repository): consumed by commit. CYLAnimatedItem is its sibling pod in
# the same repository, so it takes the same commit. CollectionViewClassifyMenu comes from feat/engine-api-core (the tag
# list's title wrapping, fold rows and long press API are not on its master yet), pinned by commit.
CYL_CLASSIFY_MENU = { :git => 'https://github.com/ChenYilong/CollectionViewClassifyMenu.git',
                      :commit => '59ce43cc72b677faa6edd5a287f01bbbb3594912' }
CYL_TAB_BAR = { :git => 'https://github.com/ChenYilong/CYLTabBarController.git',
                :commit => 'dea0951e5b26ee09e6d39a67318921fd18d44fe4' }

target 'CYLDeallocBlockExecutor' do
  pod 'CYLDeallocBlockExecutor', :path => '.'
  pod 'CYLTabBarController', CYL_TAB_BAR
  pod 'CYLAnimatedItem', CYL_TAB_BAR
  pod 'CollectionViewClassifyMenu', CYL_CLASSIFY_MENU
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings["IPHONEOS_DEPLOYMENT_TARGET"] = "15.0"
    end
  end
end
