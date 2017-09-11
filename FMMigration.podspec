Pod::Spec.new do |s|
  s.name     = 'FMMigration'
  s.version  = '0.0.1'
  s.license  = 'MIT'
  s.summary  = 'FMMigration is a schema migration for SQLite FMDB library'
  s.homepage = 'https://github.com/felipowsky/FMMigration'
  s.authors  = { 'Felipe Augusto' => '' }
  s.source   = { :git => 'https://github.com/Bipsync/FMMigration.git', :tag => "v#{s.version}" }
  s.source_files = 'FMMigration/FMMigration/*.{h,m}'
  s.requires_arc = true

  s.dependency 'FMDB/FTS'

  s.ios.deployment_target = '7.0'
end
