Pod::Spec.new do |s|
  s.name = 'SwiftTryCatch'
  s.version = '0.0.1'
  s.summary = 'Local SwiftTryCatch compatibility shim.'
  s.description = 'A local SwiftTryCatch implementation used to satisfy flutter_dynamic_icon_plus.'
  s.homepage = 'https://github.com/hulsambath/Trovara'
  s.license = { :type => 'MIT' }
  s.author = { 'Trovara' => 'support@trovara.local' }
  s.source = { :path => '.' }
  s.source_files = 'Sources/**/*.{h,m}'
  s.public_header_files = 'Sources/**/*.h'
  s.platform = :ios, '10.0'
  s.requires_arc = true
end
