require 'dl/import'
require 'dl/struct'

class HWNDError < StandardError;end

class HWND
  User32 = DL.dlopen("user32")

  WM_CLOSE    = 0x0010
  WM_KEYDOWN  = 0x0100
  WM_KEYUP    = 0x0101
  WM_CHAR     = 0x0102
  BM_CLICK    = 0x00F5
  WM_COMMAND  = 0x0111
  WM_SETTEXT  = 0x000C
  WM_GETTEXT  = 0x000D

  # GetWindows constants
  GW_HWNDFIRST = 0
  GW_HWNDLAST = 1
  GW_HWNDNEXT = 2
  GW_HWNDPREV = 3
  GW_OWNER = 4
  GW_CHILD = 5
  GW_ENABLEDPOPUP = 6
  GW_MAX = 6

  # GetAncestor constants
  GA_PARENT = 1
  GA_ROOT = 2
  GA_ROOTOWNER = 3 
  
  WIN_TRUE=-1
  WIN_FALSE=0

  attr_reader :hwnd

  # takes a hwnd handle (integer) 
  def initialize(hwnd)
    raise ArgumentError, "hwnd must be an integer greater than 0" unless hwnd.is_a?(Fixnum) && hwnd > 0
    @hwnd=hwnd
  end
  
  # length of the window text 
  def text_length
    len, args= User32['GetWindowTextLengthA', 'LL'].call(hwnd)
    len
  end

  # window text 
  def text
    buff_size=text_length+1
    buff="\000"*buff_size
    len,(passed_hwnd,buff,buff_size)= User32['GetWindowText' , 'ILSI'].call(hwnd, buff, buff_size)
    @text=buff[0...len]
  end

  # returns an enabled popup from this hwnd if one exists 
  def enabled_popup
    popup_hwnd, args=User32['GetWindow', 'ILL'].call(hwnd, GW_ENABLEDPOPUP)
    @enabled_popup= popup_hwnd > 0 && popup_hwnd != self.hwnd ? HWND.new(popup_hwnd) : nil
  end

  # returns the hwnd that owns this one 
  def owner
    owner_hwnd, args=User32['GetWindow', 'LLL'].call(hwnd, GW_OWNER)
    @owner= owner_hwnd > 0 ? HWND.new(owner_hwnd) : nil
  end
  
  # http://msdn.microsoft.com/en-us/library/ms633502(VS.85).aspx
  # Retrieves the parent window. This does not include the owner, as it does with #parent
  def ancestor_parent
    ret_hwnd, args=User32['GetAncestor', 'LLI'].call(hwnd, GA_PARENT)
    @ancestor_parent= ret_hwnd > 0 ? HWND.new(ret_hwnd) : nil
  end
  
  # http://msdn.microsoft.com/en-us/library/ms633502(VS.85).aspx
  # Retrieves the root window by walking the chain of parent windows.
  def ancestor_root
    ret_hwnd, args=User32['GetAncestor', 'LLI'].call(hwnd, GA_ROOT)
    @ancestor_root= ret_hwnd > 0 ? HWND.new(ret_hwnd) : nil
  end
  
  # http://msdn.microsoft.com/en-us/library/ms633502(VS.85).aspx
  # Retrieves the owned root window by walking the chain of parent and owner windows returned by GetParent. 
  def ancestor_root_owner
    ret_hwnd, args=User32['GetAncestor', 'LLI'].call(hwnd, GA_ROOTOWNER)
    @ancestor_root_owner= ret_hwnd > 0 ? HWND.new(ret_hwnd) : nil
  end

  # parent HWND object 
  def parent
    parent_hwnd,args=User32['GetParent', 'LL'].call(hwnd)
    @parent= parent_hwnd > 0 ? HWND.new(parent_hwnd) : nil
  end

  # sets the parent of this hwnd to the specified parent 
  def set_parent!(parent)
    parent_hwnd= parent.is_a?(HWND) ? parent.hwnd : parent
    new_parent, args=User32['SetParent', 'LLL'].call(hwnd, parent_hwnd)
    new_parent > 0 ? HWND.new(new_parent) : nil
  end

  # child of the specified hwnd? 
  def child_of?(parent)
    parent_hwnd= parent.is_a?(HWND) ? parent.hwnd : parent
    child, args=User32['IsChild', 'CLL'].call(parent_hwnd, hwnd)
    child!=WIN_FALSE
  end

  # is this applaction hung?
  def hung_app?
    hung,args= User32['IsHungAppWindow','CL'].call(hwnd)
    hung != WIN_FALSE
  end

  # name of the window class 
  def class_name
    buff_size=256
    buff="\000"*buff_size
    len, (passed_hwnd, buff, buff_size)=User32['GetClassName', 'ILpI'].call(hwnd, buff, buff_size)
    @class_name=buff.to_s[0...len]
  end
  
  # returns true if this HWND represents a window that actually exists, else false 
  def exists?
    ret, args=User32['IsWindow', 'CL'].call(hwnd)
    ret != WIN_FALSE
  end

  # returns true if this window is visible, else false
  def visible?
    ret, args=User32['IsWindowVisible', 'CL'].call(hwnd)
    ret != WIN_FALSE
  end

  # This is similar to #text
  # that one is GetWindowText(hwnd) 
  # this one is SendMessage(hwnd, WM_GETTEXT)
  # differences are documented here: http://msdn.microsoft.com/en-us/magazine/cc301438.aspx
  # and here: http://blogs.msdn.com/oldnewthing/archive/2003/08/21/54675.aspx
  def retrieve_text
    buff_size=4096
    buff="\000"*buff_size
    len, (passed_hwnd, passed_thing, buff_size, buff)= User32['SendMessage', 'ILIIS'].call(hwnd, WM_GETTEXT, buff_size, buff)
    @get_text=buff[0...len]
  end
  
  def set_text!(text)
    set, args= User32['SetWindowText', 'CLS'].call(hwnd, text)
    set != WIN_FALSE
  end

  # sets text by sending WM_SETTEXT message. is this different than SetWindowText? 
  # presumably similar to GetWindowText vs SendMessage WM_GETTEXT
  def send_set_text!(text)
    ret, args= User32['SendMessage', 'ILISS'].call(hwnd, WM_SETTEXT, '', text)
    nil
  end

  # tries to click on this HWND
  def click!
    User32['PostMessage', 'ILILL'].call(hwnd, BM_CLICK, 0, 0)
    nil
  end

  # iterates over each child, yielding a HWND object 
  # use #children to get an Enumerable object. 
  def each_child
    enum_child_windows_callback= DL.callback('ILL') do |chwnd, lparam|
      yield HWND.new(chwnd)
      WIN_TRUE
    end
    ret, args= User32['EnumChildWindows', 'IIPL'].call(hwnd, enum_child_windows_callback, 0)
    DL.remove_callback(enum_child_windows_callback)
    if ret==0
      raise HWNDError, "EnumChildWindows encountered an error"
    end
    nil
  end
  
  # returns an Enumerable object that can iterate over each child of this hwnd, 
  # yielding a HWND object 
  def children
    Children.new self
  end

  def ==(oth)
    self.eql?(oth)
  end
  def eql?(oth)
    oth.class==self.class && oth.hwnd==self.hwnd
  end
  def hash
    [self.class, self.hwnd].hash
  end

  

  # more specialized methods
  def click_child_button_text!(button_text)
    button=children.detect do |child|
      child.class_name=='Button' && button_text.is_a?(Regexp) ? child.text =~ button_text : child.text.tr('&', '').downcase==button_text.to_s.tr('&', '').downcase
    end
    raise HWNDError, "Button #{button_text} not found" unless button
    button.click!
  end


  # Iterates over every hwnd yielding an HWND object. 
  # use HWND::All if you want an Enumerable object. 
  def self.each_hwnd
    enum_windows_callback= DL.callback('ILL') do |hwnd,lparam|
      yield HWND.new(hwnd)
      WIN_TRUE
    end
    ret, args=User32['EnumWindows', 'IPL'].call(enum_windows_callback, 0)
    DL.remove_callback(enum_windows_callback)
    if ret==0
      raise HWNDError, "EnumWindows ecountered an error"
    end
    nil
  end
  
  # returns the first HWND found whose text matches what is given
  def self.find_first_by_text(text)
    HWND::All.detect do |hwnd|
      text===hwnd.text # use triple-equals so regexps try to match, strings see if equal 
    end
  end

  # returns all HWND objects found whose text matches what is given
  def self.find_all_by_text(text)
    HWND::All.select do |hwnd|
      text===hwnd.text # use triple-equals so regexps try to match, strings see if equal 
    end
  end

  # raises an error if more than one window matching given text is found
  # so that you can be sure you are attaching to the right one (because it's the only one)
  def self.find_only_by_text(text)
    matched=HWND::All.select do |hwnd|
      text===hwnd.text
    end
    if matched.size != 1
      raise HWNDError, "Found #{matched.size} windows matching #{text.inspect}; there should be one"
    else
      return matched.first
    end
  end

  # Enumerable object that iterates over every available HWND 
  module All
    def self.each
      HWND.each_hwnd do |hwnd|
        yield hwnd
      end
    end
    extend Enumerable
  end

  # instantiates Enumerable objects that iterate over a HWND's children. 
  class Children
    attr_reader :parenthwnd
    def initialize(parenthwnd)
      @parenthwnd=parenthwnd
    end
    def each
      parenthwnd.each_child do |chwnd|
        yield chwnd
      end
    end
    include Enumerable
  end

end
