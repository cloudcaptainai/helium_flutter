#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint helium_stripe.podspec` to validate before publishing.
#
require 'yaml'
pubspec = YAML.load_file(File.join('..', 'pubspec.yaml'))

Pod::Spec.new do |s|
  s.name             = 'helium_stripe'
  s.version          = pubspec['version']
  s.summary          = 'Helium Stripe One Tap Purchase SDK for Flutter'
  s.description      = <<-DESC
A Flutter plugin that integrates the Helium SDK with Stripe One Tap Purchase for iOS.
                       DESC
  s.homepage         = 'https://tryhelium.com'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'CloudCaptainAI' => 'https://github.com/cloudcaptainai' }
  s.source           = { :git => 'https://github.com/cloudcaptainai/helium_flutter.git', :tag => s.version }
  s.source_files = 'helium_stripe/Sources/helium_stripe/**/*'
  s.dependency 'Flutter'

  # note that the dependency in Package.swift is what's actually used for Helium... we might be able to remove this but safer to keep in for now
  s.dependency 'Helium', '4.1.8'
  s.dependency 'StripeOneTapPurchase', '1.0.6'

  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.7'
end
