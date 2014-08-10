Pod::Spec.new do |s|
  s.name     = 'Bitheri'
  s.version  = '0.0.1'
  s.license  = 'Apache License, Version 2.0'
  s.summary  = 'bither\'s ios framework'
  s.homepage = 'http://bither.net'
  s.social_media_url = ''
  s.authors  = { 'Zhou Qi' => 'bitwolaiye@gmail.com' }
  s.source   = { :git => 'git@gitlab.com:bither/bitheri.git', :submodules => true, :tag => "v#{s.version}"}
  s.requires_arc = true

  s.platform     = :ios
  s.ios.deployment_target = '7.0'

  s.source_files = 'Bitheri/Bitheri.{h,m}', 'Bitheri/{Models,Categories,Core,DatabaseProviders,Script,Log}/*.{h,m}'

  s.dependency 'OpenSSL', '1.0.1'
  s.dependency 'Reachability'
  s.dependency 'FMDB'
  s.dependency 'CocoaLumberjack'

end