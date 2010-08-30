class WinWindow;end
WinWindow::Version = '0.4.0'

WinWindow::Spec = Gem::Specification.new do |s|
  s.name = 'winwindow'
  s.version = WinWindow::Version
  s.summary = 'A Ruby library to wrap windows API calls relating to hWnd window handles. '
  s.description = s.summary
  s.author = 'Ethan'
  s.email = 'vapir@googlegroups.com'
  s.homepage = 'http://winwindow.vapir.org/'

  s.platform = Gem::Platform::RUBY
  s.requirements = ["Microsoft Windows, probably with some sort of NT kernel"]
  s.require_path = 'lib'

  s.add_dependency 'ffi', '>= 0.5.4'

#  s.add_development_dependency 'minitest' # for winwindow_test.rb. not going to say the gem is needed because it's built into 1.9.*, but you need the gem for 1.8.*

  s.rdoc_options += %w(--charset UTF-8 --show-hash --inline-source --main WinWindow --title WinWindow --tab-width 2 lib/winwindow.rb)

  s.test_files = [
    'test/winwindow_test.rb'
  ]

  s.files = [
    #'History.txt', #TODO
    #'README.txt', #TODO
    'lib/winwindow.rb', # main WinWindow class
    'lib/winwindow/ext.rb', # language-extension type stuff (external to what WinWindow does)
  ]
end
