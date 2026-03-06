Pod::Spec.new do |s|
  s.name             = 'cactus'
  s.version          = '1.9'
  s.summary          = 'Cactus on-device inference engine'
  s.homepage         = 'https://github.com/cactus-compute/cactus'
  s.license          = { :type => 'MIT' }
  s.author           = 'Cactus Compute'
  s.platform         = :ios, '14.0'
  s.source           = { :path => '.' }
  s.vendored_frameworks = 'cactus.xcframework'
end
