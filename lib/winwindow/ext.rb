# extensions to the language which are external to what the WinWindow library itself does 

class WinWindow # :nodoc:all
  
  # takes given options and default options, and optionally a list of additional allowed keys not specified in default options
  # (this is useful when you want to pass options along to another function but don't want to specify a default that will
  # clobber that function's default) 
  # raises ArgumentError if the given options have an invalid key (defined as one not
  # specified in default options or other_allowed_keys), and sets default values in given options where nothing is set.
  def self.handle_options(given_options, default_options, other_allowed_keys=[]) # :nodoc:
    given_options=given_options.dup
    unless (unknown_keys=(given_options.keys-default_options.keys-other_allowed_keys)).empty?
      raise ArgumentError, "Unknown options: #{(given_options.keys-default_options.keys).map(&:inspect).join(', ')}. Known options are #{(default_options.keys+other_allowed_keys).map(&:inspect).join(', ')}"
    end
    (default_options.keys-given_options.keys).each do |key|
      given_options[key]=default_options[key]
    end
    given_options
  end
  
  def handle_options(*args) # :nodoc:
    self.class.handle_options(*args)
  end
  # Default exception class raised by Waiter when a timeuot is reached 
  class WaiterError < StandardError # :nodoc:
  end
  module Waiter # :nodoc:all
    # Tries for +time+ seconds to get the desired result from the given block. Stops when either:
    # 1. The :condition option (which should be a proc) returns true (that is, not false or nil)
    # 2. The block returns true (that is, anything but false or nil) if no :condition option is given
    # 3. The specified amount of time has passed. By default a WaiterError is raised. 
    #    If :exception option is given, then if it is nil, no exception is raised; otherwise it should be
    #    an exception class or an exception instance which will be raised instead of WaiterError
    #
    # Returns the value of the block, which can be handy for things that return nil on failure and some 
    # other object on success, like Enumerable#detect for example: 
    #  found_thing=Waiter.try_for(30){ all_things().detect{|thing| thing.name=="Bill" } }
    #
    # Examples:
    #  Waiter.try_for(30) do
    #    Time.now.year == 2015
    #  end
    # Raises a WaiterError unless it is called between the last 30 seconds of December 31, 2014 and the end of 2015
    #
    #  Waiter.try_for(365*24*60*60, :interval => 0.1, :exception => nil, :condition => proc{ 2+2==5 }) do
    #    STDERR.puts "any decisecond now ..."
    #  end
    # 
    # Complains to STDERR for one year, every tenth of a second, as long as 2+2 does not equal 5. Does not 
    # raise an exception if 2+2 does not become equal to 5. 
    def self.try_for(time, options={})
      unless time.is_a?(Numeric) && options.is_a?(Hash)
        raise TypeError, "expected arguments are time (a numeric) and, optionally, options (a Hash). received arguments #{time.inspect} (#{time.class}), #{options.inspect} (#{options.class})"
      end
      options=WinWindow.handle_options(options, {:interval => 0.5, :condition => proc{|_ret| _ret}, :exception => WaiterError})
      started=Time.now
      begin
        ret=yield
        break if options[:condition].call(ret)
        sleep options[:interval]
      end while Time.now < started+time && !options[:condition].call(ret)
      if options[:exception] && !options[:condition].call(ret)
        ex=if options[:exception].is_a?(Class)
          options[:exception].new("Waiter waited #{time} seconds and condition was not met")
        else
          options[:exception]
        end
        raise ex
      end
      ret
    end
  end
end
module Kernel # :nodoc:
  # this is the Y-combinator, which allows anonymous recursive functions. for a simple example, 
  # to define a recursive function to return the length of an array:
  #
  #  length = ycomb do |len|
  #    proc{|list| list == [] ? 0 : len.call(list[1..-1]) }
  #  end
  #
  # see https://secure.wikimedia.org/wikipedia/en/wiki/Fixed_point_combinator#Y_combinator
  # and chapter 9 of the little schemer, available as the sample chapter at http://www.ccs.neu.edu/home/matthias/BTLS/
  def ycomb
    proc{|f| f.call(f) }.call(proc{|f| yield proc{|*x| f.call(f).call(*x) } })
  end
  module_function :ycomb
end
