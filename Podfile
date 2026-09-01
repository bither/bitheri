source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '12.0'
workspace 'Bitheri.xcworkspace'
project 'Bitheri.xcodeproj'

target 'Bitheri' do
  pod 'OpenSSL', :git => 'https://github.com/bither/OpenSSL.git', :branch => 'master'
  pod 'FMDB', '~> 2.3'
  pod 'Reachability', '~> 3.2.0'
  pod 'CocoaLumberjack', '~> 1.9.1'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |configuration|
      configuration.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
    end
  end

  Dir.glob("#{installer.sandbox.root}/Reachability/Reachability.{h,m}").each do |file|
    File.chmod(0644, file)
    File.write(file, File.read(file).gsub(/^#import <netinet6\/in6\.h>\n/, ''))
  end
end
