Pod::Spec.new do |s|
  s.name = 'RegionSignalKit'
  s.version = '0.3.0'
  s.summary = 'Device setting and optional IP country checks for iOS.'
  s.description = 'Evaluates device settings and optional IP country lookup, reporting unknown when checks cannot be verified.'
  s.homepage = 'https://github.com/kelegogosu-source/RegionSignalKit'
  s.license = { :type => 'MIT', :file => 'LICENSE' }
  s.author = { 'kelegogosu-source' => 'kelegogosu-source@users.noreply.github.com' }
  s.source = { :git => 'https://github.com/kelegogosu-source/RegionSignalKit.git', :tag => s.version.to_s }
  s.ios.deployment_target = '15.0'
  s.swift_version = '5.0'
  s.source_files = 'Sources/RegionSignalKit/**/*.swift'
end
