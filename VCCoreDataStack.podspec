Pod::Spec.new do |s|
  s.name     = 'VCCoreDataStack'
  s.version  = '1.0.0'
  s.ios.deployment_target = '6.1'
  s.license  = 'MIT'
  s.summary  = 'A clean CoreData stack.'
  s.homepage = 'https://github.com/davinc/VCCoreDataStack'
  s.authors   = { 'Vinay Chavan' => 'davinc@me.com' }
  s.source   = { :git => 'https://github.com/davinc/VCCoreDataStack.git', :tag => s.version.to_s }

  s.description = 'A clean CoreData stack.'

  s.source_files = 'VCCoreDataStack.{h,m}'
  s.framework    = 'CoreData'
  s.requires_arc = true
end
