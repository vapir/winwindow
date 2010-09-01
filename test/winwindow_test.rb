libdir = File.join(File.dirname(__FILE__), '..', 'lib')
$LOAD_PATH.unshift(libdir) unless $LOAD_PATH.any?{|p| File.expand_path(p) == File.expand_path(libdir) }

require 'winwindow'

require 'minitest/unit'
MiniTest::Unit.autorun

class TestWinWindow < MiniTest::Unit::TestCase
  def setup
    @ie_ole, @win = *new_ie_ole
  end
  
  def teardown
    @ie_ole.Quit
  end
  
  # make a new IE win32ole window for testing. also send it to the given url (default is google) and wait for that to load. 
  def new_ie_ole(url='http://google.com')
    require 'win32ole'
    ie_ole=nil
    WinWindow::Waiter.try_for(32) do
      begin
        ie_ole = WIN32OLE.new('InternetExplorer.Application')
        ie_ole.Visible=true
        true
      rescue WIN32OLERuntimeError, NoMethodError
        false
      end
    end
    ie_ole.Navigate url
    WinWindow::Waiter.try_for(32, :exception => "The browser's readyState did not become ready for interaction") do
      [3, 4].include?(ie_ole.readyState)
    end
    [ie_ole, WinWindow.new(ie_ole.HWND)]
  end
  
  def with_ie(*args)
    ie_ole, win = *new_ie_ole(*args)
    begin
      yield ie_ole, win
    ensure
      ie_ole.Quit
    end
  end
  
  def launch_popup(text="popup!", ie_ole=@ie_ole)
    raise ArgumentError, "No double-quotes or backslashes, please" if text =~ /["\\]/
    ie_ole.Navigate('javascript:alert("'+text+'")')
    popup = WinWindow::Waiter.try_for(16, :exception => "No popup appeared on the browser!"){ WinWindow.new(@ie_ole.HWND).enabled_popup }
  end
  
  def with_popup(text="popup!", ie_ole=@ie_ole)
    popup = launch_popup(text, ie_ole)
    begin
      yield popup
    ensure
      popup.click_child_button_try_for!(//, 8)
    end
  end
  
  def assert_eventually(message=nil, options={}, &block)
    options[:exception] ||= nil
    timeout = options.delete(:timeout) || 16
    result = WinWindow::Waiter.try_for(timeout, options, &block)
    message ||= "Expected block to eventually yield true; after #{timeout} seconds it was #{result}"
    assert result, message
  end
  
  def test_hwnd
    assert_equal @win.hwnd, @ie_ole.HWND
  end
  def test_inspect
    assert_includes @win.inspect, @win.hwnd.to_s
    assert_includes @win.inspect, @win.retrieve_text
  end
  def test_text
    assert_match /google/i, @win.retrieve_text
    assert_match /google/i, @win.text # might fail? it is not meant to retrieve text of a control in another application? well, it seems to work. 
  end
  def test_set_text
    assert_eventually do
      @win.set_text! 'foobar'
      @win.text=='foobar'
    end
    assert_eventually do
      @win.send_set_text! 'bazqux'
      @win.retrieve_text=='bazqux'
    end
  end
  def test_popup
    text='popup!'
    with_popup(text) do
      assert_instance_of(WinWindow, @win.enabled_popup)
      assert(@win.enabled_popup.children.any?{|child| child.text.include?(text) }, "Enabled popup should include the text #{text}")
      assert_equal(@win.enabled_popup, @win.last_active_popup)
    end
  end
  def test_owner_ancestors_parent_child
    with_popup do |popup|
      assert_equal(popup.owner, @win)
      assert_equal(popup.ancestor_parent, WinWindow.desktop_window)
      assert_equal(popup.ancestor_root, popup)
      assert_equal(popup.ancestor_root_owner, @win)
      assert_equal(popup.parent, @win)
      button = popup.child_button(//)
      assert_equal(button.owner, nil)
      assert_equal(button.ancestor_parent, popup)
      assert_equal(button.ancestor_root, popup)
      assert_equal(button.ancestor_root_owner, @win)
      assert_equal(button.parent, popup)
      assert(button.child_of?(popup))
    end
  end
  def test_set_parent
    with_ie do |ie_ole2, win2|
      with_popup do |popup|
        assert_equal WinWindow.desktop_window, popup.ancestor_parent
        popup.set_parent! win2
        assert_equal win2, popup.ancestor_parent
      end
    end
  end
  def test_hung_app
    assert !@win.hung_app?
    # I don't know how to make IE freeze to test the true case (you wouldn't expect making IE freeze to be a diffult thing, would you?)
  end
  def test_class_name
    with_popup do |popup|
      assert popup.children.any?{|child| child.class_name=="Static"}
      assert popup.children.any?{|child| child.class_name=="Button"}
      assert popup.real_class_name == popup.class_name
    end
  end
  def test_thread_id_process_id
    # I don't know how to properly test this. just check that it looks id-like 
    assert @win.thread_id.is_a?(Integer)
    assert @win.thread_id > 0
    assert @win.process_id.is_a?(Integer)
    assert @win.process_id > 0
  end
  def test_exists
    temp_ie, twin = *new_ie_ole
    assert twin.exists?
    temp_ie.Quit
    assert_block do
      WinWindow::Waiter.try_for(8) do
        !twin.exists?
      end
    end
  end
  def test_visible
    @ie_ole.Visible = true
    assert @win.visible?
    @ie_ole.Visible = false
    assert !@win.visible?
  end
  def test_min_max_iconic_foreground
    with_ie do |ie_ole2, win2|
      @win.close! # this is actually minimize 
      assert @win.iconic?
      @win.really_set_foreground!
      assert @win.foreground?
      win2.really_set_foreground!
      assert win2.foreground?
      # I don't know what to do with the rest of these - no idea what the differenc
      # is between most of them, and no real way to test their effects. 
      # but there's not really much to screw up. 
      # I'll just assume that if they don't error all is well. 
      @win.set_foreground!
      @win.switch_to!
      @win.bring_to_top!
      @win.hide!
      @win.show_normal!
      @win.show_minimized!
      @win.show_maximized!
      @win.maximize!
      @win.show_no_activate!
      @win.show!
      @win.minimize!
      @win.show_min_no_active!
      @win.show_na!
      @win.restore!
      @win.show_default!
      @win.force_minimize!
    end
  end
  def test_end_close_destroy
    @win.destroy! 
    # no idea when this ever does anything, just seems to return false. will be content with it not erroring, I suppose. 
    @ie_ole, @win = *new_ie_ole unless @win.exists?

    assert_eventually do
      @win.really_set_foreground!
      @win.end_task!
      !@win.exists?
    end
    @ie_ole, @win = *new_ie_ole unless @win.exists?
    
    assert_eventually do
      @win.really_set_foreground!
      @win.send_close!
      !@win.exists?
    end
    @ie_ole, @win = *new_ie_ole unless @win.exists?
  end
  def test_click
    # dismissing the popup relies on clicking; we'll use that to test. 
    with_popup do
      assert @win.enabled_popup
    end
    assert !@win.enabled_popup
  end
  def test_screen_capture
    # writing to file tests all the screen capture functions (at least that they don't error)
    filename = 'winwindow.bmp'
    @win.capture_to_bmp_file filename
    assert File.exists?(filename)
    assert File.size(filename) > 0
    # todo: check it's valid bmp with the right size (check #window_rect/#client_rect)? use rmagick? 
    File.unlink filename
  end
  def test_children_and_all
    assert @win.children.is_a?(Enumerable)
    assert WinWindow::All.is_a?(Enumerable)
    cwins=[]
    @win.each_child do |cwin|
      assert cwin.is_a?(WinWindow)
      assert cwin.exists?
      assert cwin.child_of?(@win)
      cwins << cwin
    end
    assert_equal @win.children.to_a, cwins
    assert cwins.size > 0
    all_wins = []
    WinWindow.each_window do |win|
      assert win.is_a?(WinWindow)
      assert win.exists?
      all_wins << win
    end
    assert_equal WinWindow::All.to_a, all_wins
    assert all_wins.size > 0
  end
  def test_children_recursive
    cwins = []
    @win.recurse_each_child do |cwin|
      assert cwin.is_a?(WinWindow)
      assert cwin.exists?
      #assert cwin.child_of?(@win)
      cwins << cwin
    end
    assert_equal @win.children_recursive.to_a, cwins
    require 'set'
    assert Set.new(@win.children).subset?(Set.new(@win.children_recursive))
  end
  def test_system_error
    assert_raises(WinWindow::SystemError) do
      begin
        @win.recurse_each_child(:rescue_enum_child_windows => false) { nil }
      rescue WinWindow::SystemError # not really rescuing, just checking info
        assert_equal 'EnumChildWindows', $!.function
        assert $!.code.is_a?(Integer)
        raise
      end
    end
  end
  def test_finding
    assert WinWindow.find_first_by_text(//).is_a?(WinWindow)
    found_any = false
    WinWindow.find_all_by_text(//).each do |win|
      assert win.is_a?(WinWindow)
      assert win.exists?
      found_any = true
    end
    assert found_any
    assert(WinWindow.find_only_by_text(@win.retrieve_text)==@win)
    with_ie do
      assert_raises(WinWindow::MatchError) do
        WinWindow::Waiter.try_for(32) do # this doesn't always come up immediately, so give it a moment 
          WinWindow.find_only_by_text(@win.retrieve_text)
          false
        end
      end
    end
  end
  def test_foreground_desktop
    assert WinWindow.foreground_window.is_a?(WinWindow)
    assert WinWindow.foreground_window.exists?
    assert WinWindow.desktop_window.is_a?(WinWindow)
    assert WinWindow.desktop_window.exists?
  end
end
