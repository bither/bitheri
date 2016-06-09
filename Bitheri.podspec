Pod::Spec.new do |s|
  s.name     = 'Bitheri'
  s.version  = '1.5.1'
  s.license  = 'Apache License, Version 2.0'
  s.summary  = 'bither\'s ios framework'
  s.homepage = 'http://bither.net'
  s.social_media_url = ''
  s.authors  = { 'bither' => 'bither@gmail.com' }
  s.source   = { :git => 'git@github.com:bither/bitheri.git', :submodules => true, :tag => "v#{s.version}"}
  s.requires_arc = true

  s.platform     = :ios
  s.ios.deployment_target = '7.0'

  s.source_files = 'Bitheri/Bitheri.{h,m}', 'Bitheri/{Models,Categories,Core,DatabaseProviders,Script,Utils,Log}/*.{h,m}'

  s.dependency 'OpenSSL', '1.0.1j'
  s.dependency 'Reachability', '~> 3.1.1'
  s.dependency 'FMDB', '~> 2.3'
  s.dependency 'CocoaLumberjack', '~> 1.9.1'

end