Pod::Spec.new do |s|
  s.name         = "CYLDeallocBlockExecutor"
  s.version      = "1.1.2"
  s.summary      = "When object(iOS) is nil,then it can automaticely execute a block "
  s.description  = "It can observe object(iOS) being nil, or in other words, being dealloced, then automaticely execute a block."
  s.homepage     = "https://github.com/ChenYilong/CYLDeallocBlockExecutor"
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { "ChenYilong" => "luohanchenyilong@163.com" }
  s.platform     = :ios, '6.0'
  s.source       = { :git => "https://github.com/ChenYilong/CYLDeallocBlockExecutor.git", :tag => s.version.to_s }
  s.source_files  = 'CYLDeallocBlockExecutor', 'CYLDeallocBlockExecutor/**/*.{h,m}'
  s.requires_arc = true
end
