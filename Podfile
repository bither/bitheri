source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '15.6'

target 'Bitheri' do
  pod 'OpenSSL', :git => 'https://github.com/bither/OpenSSL.git', :branch => 'master'
  pod 'FMDB', '~> 2.3'
  pod 'Reachability', '~> 3.7.7'
  pod 'CocoaLumberjack', '~> 1.9.1'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |configuration|
      configuration.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.6'
    end
  end
end
