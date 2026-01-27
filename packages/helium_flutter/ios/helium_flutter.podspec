#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint helium_flutter.podspec` to validate before publishing.
#
require 'yaml'
pubspec = YAML.load_file(File.join('..', 'pubspec.yaml'))

Pod::Spec.new do |s|
  s.name             = 'helium_flutter'
  s.version          = pubspec['version']
  s.summary          = 'Helium SDK for Flutter'
  s.description      = <<-DESC
A Flutter plugin that integrates the Helium SDK for iOS.
                       DESC
  s.homepage         = 'https://tryhelium.com'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'CloudCaptainAI' => 'https://github.com/cloudcaptainai' }
  s.source           = { :git => 'https://github.com/cloudcaptainai/helium_flutter.git', :tag => s.version }
  s.source_files = 'helium_flutter/Sources/helium_flutter/**/*'
  s.dependency 'Flutter'

  # note that the dependency in Package.swift is what's actually used... we might be able to remove this but safer to keep in for now
  s.dependency 'Helium', '4.1.0'

  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'helium_flutter_privacy' => ['helium_flutter/Sources/helium_flutter/PrivacyInfo.xcprivacy']}
end
