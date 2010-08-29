def rdoc(hash)
  default_stuff = {:format => 'html', :"tab-width" => 2, :"show-hash" => nil, :"inline-source" => nil, :template => 'hanna', :charset => 'UTF-8'}
  hash = default_stuff.merge(hash)
  options = (hash.keys-[:files]).inject([]) do |list, key|
    value = hash[key]
    ddkey="--#{key}"
    list + case value
    when nil
      [ddkey]
    when Array
      value.inject([]){|vlist, value_part| vlist+[ddkey, value_part.to_s]}
    else
      [ddkey, value.to_s]
    end
  end
  options+=(hash[:files] || [])
  if hash[:op] && File.exists?(hash[:op])
    require 'fileutils'
    FileUtils.rm_r(hash[:op])
  end

  gem 'hanna'
  require 'hanna/version'
  Hanna::require_rdoc
  require 'rdoc/rdoc'
  RDoc::RDoc.new.document(options)
end

desc 'Build WinWindow rdoc'
task :rdoc do
  rdoc(:op => 'rdoc', :title => 'WinWindow', :main => 'WinWindow', :files => ['lib/winwindow.rb'])
end
