platform :ios, '16.0'
source 'https://cdn.cocoapods.org/'

target 'MengBao' do
  inhibit_all_warnings!

  # 高德地图 3D SDK（地图渲染 + 内置定位）
  pod 'AMap3DMap'
  # 高德搜索 SDK（周边 POI 搜索：预防接种门诊）
  pod 'AMapSearch'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
      config.build_settings['ENABLE_BITCODE'] = 'NO'
      config.build_settings['ENABLE_MODULE_VERIFIER'] = 'NO'
      config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
      config.build_settings['EXPANDED_CODE_SIGN_IDENTITY'] = ''
    end
  end
end
