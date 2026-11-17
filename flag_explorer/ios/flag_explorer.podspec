#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flag_explorer.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flag_explorer'
  s.version          = '0.0.1'
  s.summary          = 'Reusable 3D MapKit Globe with GeoJSON Country Highlighting for Flutter.'
  s.description      = <<-DESC
A high-performance iOS Flutter plugin embedding Apple MapKit 3D satellite globe with pure-vector glowing country overlays and point-in-polygon country detection.
                       DESC
  s.homepage         = 'https://github.com/example/flag_explorer'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Flag Explorer Team' => 'dev@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'flag_explorer/Sources/flag_explorer/**/*.swift'
  s.resource_bundles = {
    'flag_explorer_resources' => ['flag_explorer/Sources/flag_explorer/Resources/**/*']
  }
  s.dependency 'Flutter'
  s.platform = :ios, '16.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
