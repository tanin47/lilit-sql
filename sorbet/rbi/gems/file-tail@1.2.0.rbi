# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `file-tail` gem.
# Please instead update this file by running `bin/tapioca gem file-tail`.

# This module can be included in your own File subclasses or used to extend
# files you want to tail.
#
# source://file-tail//lib/file/tail.rb#4
module File::Tail
  # The callback is called with _self_ as an argument after a reopen has
  # occured. This allows a tailing script to find out, if a logfile has been
  # rotated.
  #
  # source://file-tail//lib/file/tail.rb#71
  def after_reopen(&block); end

  # Rewind the last <code>n</code> lines of this file, starting
  # from the end. The default is to start tailing directly from the
  # end of the file.
  #
  # The additional argument <code>bufsize</code> is
  # used to determine the buffer size that is used to step through
  # the file backwards. It defaults to the block size of the
  # filesystem this file belongs to or 8192 bytes if this cannot
  # be determined.
  #
  # source://file-tail//lib/file/tail.rb#121
  def backward(n = T.unsafe(nil), bufsize = T.unsafe(nil)); end

  # If this attribute is set to a true value, File::Fail's tail method
  # raises a BreakException if the end of the file is reached.
  #
  # source://file-tail//lib/file/tail.rb#86
  def break_if_eof; end

  # If this attribute is set to a true value, File::Fail's tail method
  # raises a BreakException if the end of the file is reached.
  #
  # source://file-tail//lib/file/tail.rb#86
  def break_if_eof=(_arg0); end

  # Default buffer size, that is used while going backward from a file's end.
  # This defaults to nil, which means that File::Tail attempts to derive this
  # value from the filesystem block size.
  #
  # source://file-tail//lib/file/tail.rb#95
  def default_bufsize; end

  # Default buffer size, that is used while going backward from a file's end.
  # This defaults to nil, which means that File::Tail attempts to derive this
  # value from the filesystem block size.
  #
  # source://file-tail//lib/file/tail.rb#95
  def default_bufsize=(_arg0); end

  # Skip the first <code>n</code> lines of this file. The default is to don't
  # skip any lines at all and start at the beginning of this file.
  #
  # source://file-tail//lib/file/tail.rb#102
  def forward(n = T.unsafe(nil)); end

  # The start value of the sleep interval. This value
  # goes against <code>max_interval</code> if the tailed
  # file is silent for a sufficient time.
  #
  # source://file-tail//lib/file/tail.rb#54
  def interval; end

  # The start value of the sleep interval. This value
  # goes against <code>max_interval</code> if the tailed
  # file is silent for a sufficient time.
  #
  # source://file-tail//lib/file/tail.rb#54
  def interval=(_arg0); end

  # Override the default line separator
  #
  # source://file-tail//lib/file/tail.rb#98
  def line_separator; end

  # Override the default line separator
  #
  # source://file-tail//lib/file/tail.rb#98
  def line_separator=(_arg0); end

  # The maximum interval File::Tail sleeps, before it tries
  # to take some action like reading the next few lines
  # or reopening the file.
  #
  # source://file-tail//lib/file/tail.rb#49
  def max_interval; end

  # The maximum interval File::Tail sleeps, before it tries
  # to take some action like reading the next few lines
  # or reopening the file.
  #
  # source://file-tail//lib/file/tail.rb#49
  def max_interval=(_arg0); end

  # If this attribute is set to a true value, File::Tail persists
  # on reopening a deleted file waiting <code>max_interval</code> seconds
  # between the attempts. This is useful if logfiles are
  # moved away while rotation occurs but are recreated at
  # the same place after a while. It defaults to true.
  #
  # source://file-tail//lib/file/tail.rb#61
  def reopen_deleted; end

  # If this attribute is set to a true value, File::Tail persists
  # on reopening a deleted file waiting <code>max_interval</code> seconds
  # between the attempts. This is useful if logfiles are
  # moved away while rotation occurs but are recreated at
  # the same place after a while. It defaults to true.
  #
  # source://file-tail//lib/file/tail.rb#61
  def reopen_deleted=(_arg0); end

  # If this attribute is set to a true value, File::Tail
  # attempts to reopen it's tailed file after
  # <code>suspicious_interval</code> seconds of silence.
  #
  # source://file-tail//lib/file/tail.rb#66
  def reopen_suspicious; end

  # If this attribute is set to a true value, File::Tail
  # attempts to reopen it's tailed file after
  # <code>suspicious_interval</code> seconds of silence.
  #
  # source://file-tail//lib/file/tail.rb#66
  def reopen_suspicious=(_arg0); end

  # If this attribute is set to a true value, File::Fail's tail method
  # just returns if the end of the file is reached.
  #
  # source://file-tail//lib/file/tail.rb#90
  def return_if_eof; end

  # If this attribute is set to a true value, File::Fail's tail method
  # just returns if the end of the file is reached.
  #
  # source://file-tail//lib/file/tail.rb#90
  def return_if_eof=(_arg0); end

  # This attribute is the invterval in seconds before File::Tail
  # gets suspicious that something has happend to it's tailed file
  # and an attempt to reopen it is made.
  #
  # If the attribute <code>reopen_suspicious</code> is
  # set to a non true value, suspicious_interval is
  # meaningless. It defaults to 60 seconds.
  #
  # source://file-tail//lib/file/tail.rb#82
  def suspicious_interval; end

  # This attribute is the invterval in seconds before File::Tail
  # gets suspicious that something has happend to it's tailed file
  # and an attempt to reopen it is made.
  #
  # If the attribute <code>reopen_suspicious</code> is
  # set to a non true value, suspicious_interval is
  # meaningless. It defaults to 60 seconds.
  #
  # source://file-tail//lib/file/tail.rb#82
  def suspicious_interval=(_arg0); end

  # This method tails this file and yields to the given block for
  # every new line that is read.
  # If no block is given an array of those lines is
  # returned instead. (In this case it's better to use a
  # reasonable value for <code>n</code> or set the
  # <code>return_if_eof</code> or <code>break_if_eof</code>
  # attribute to a true value to stop the method call from blocking.)
  #
  # If the argument <code>n</code> is given, only the next <code>n</code>
  # lines are read and the method call returns. Otherwise this method
  # call doesn't return, but yields to block for every new line read from
  # this file for ever.
  #
  # source://file-tail//lib/file/tail.rb#169
  def tail(n = T.unsafe(nil), &block); end

  private

  # source://file-tail//lib/file/tail.rb#292
  def output_debug_information; end

  # source://file-tail//lib/file/tail.rb#225
  def preset_attributes; end

  # source://file-tail//lib/file/tail.rb#198
  def read_line(&block); end

  # source://file-tail//lib/file/tail.rb#274
  def reopen_file(mode); end

  # source://file-tail//lib/file/tail.rb#239
  def restat; end

  # source://file-tail//lib/file/tail.rb#256
  def sleep_interval; end
end

# The BreakException is raised if the <code>break_if_eof</code>
# attribute is set to a true value and the end of tailed file
# is reached.
#
# source://file-tail//lib/file/tail.rb#26
class File::Tail::BreakException < ::File::Tail::TailException; end

# The DeletedException is raised if a file is
# deleted while tailing it.
#
# source://file-tail//lib/file/tail.rb#17
class File::Tail::DeletedException < ::File::Tail::TailException; end

# This class can be used to coordinate tailing of many files, which have
# been added to the group.
#
# source://file-tail//lib/file/tail/group.rb#7
class File::Tail::Group
  # Creates a new File::Tail::Group instance.
  #
  # The following options can be given as arguments:
  # :files:: an array of files (or filenames to open) that are placed into
  #          the group.
  #
  # @return [Group] a new instance of Group
  #
  # source://file-tail//lib/file/tail/group.rb#13
  def initialize(opts = T.unsafe(nil)); end

  # Add a file (IO instance) or filename (responding to to_str) to this
  # group.
  #
  # source://file-tail//lib/file/tail/group.rb#27
  def <<(file_or_filename); end

  # Add a file (IO instance) or filename (responding to to_str) to this
  # group.
  #
  # source://file-tail//lib/file/tail/group.rb#27
  def add(file_or_filename); end

  # Add the IO instance +file+ to this group.
  #
  # source://file-tail//lib/file/tail/group.rb#38
  def add_file(file); end

  # Add a file created by opening +filename+ to this group after stepping
  # +n+ lines backwards from the end of it.
  #
  # source://file-tail//lib/file/tail/group.rb#45
  def add_filename(filename, n = T.unsafe(nil)); end

  # Iterate over all files contained in this group yielding to +block+ for
  # each of them.
  #
  # source://file-tail//lib/file/tail/group.rb#54
  def each_file(&block); end

  # Iterate over all tailers in this group yielding to +block+ for each of
  # them.
  #
  # source://file-tail//lib/file/tail/group.rb#60
  def each_tailer(&block); end

  # Stop all tailers in this group at once.
  #
  # source://file-tail//lib/file/tail/group.rb#65
  def stop; end

  # Tail all the lines of all the files in the Tail::Group instance, that
  # is yield to each of them.
  #
  # Every line is extended with the LineExtension module, that adds some
  # methods to the line string. To get the path of the file this line was
  # received from call line.file.path.
  #
  # source://file-tail//lib/file/tail/group.rb#77
  def tail; end

  private

  # source://file-tail//lib/file/tail/group.rb#89
  def setup_file_tailer(file); end

  # Wait until new input is receіved on any of the tailers in the group. If
  # so call +block+ with all of these trailers as an argument.
  #
  # source://file-tail//lib/file/tail/group.rb#112
  def wait_for_activity(&block); end

  class << self
    # Creates a group for +files+ (IO instances or filename strings).
    #
    # source://file-tail//lib/file/tail/group.rb#21
    def [](*files); end
  end
end

# This module is used to extend all lines received via one of the tailers
# of a File::Tail::Group.
#
# source://file-tail//lib/file/tail/line_extension.rb#5
module File::Tail::LineExtension
  # The file as a File instance this line was read from.
  #
  # source://file-tail//lib/file/tail/line_extension.rb#7
  def file; end

  # This is the tailer this line was received from.
  #
  # source://file-tail//lib/file/tail/line_extension.rb#12
  def tailer; end
end

# This is an easy to use Logfile class that includes
# the File::Tail module.
#
# === Usage
# The unix command "tail -10f filename" can be emulated like that:
#  File::Tail::Logfile.open(filename, :backward => 10) do |log|
#    log.tail { |line| puts line }
#  end
#
# Or a bit shorter:
#  File::Tail::Logfile.tail(filename, :backward => 10) do |line|
#    puts line
#  end
#
# To skip the first 10 lines of the file do that:
#  File::Tail::Logfile.open(filename, :forward => 10) do |log|
#    log.tail { |line| puts line }
#  end
#
# The unix command "head -10 filename" can be emulated like that:
#  File::Tail::Logfile.open(filename, :return_if_eof => true) do |log|
#    log.tail(10) { |line| puts line }
#  end
#
# source://file-tail//lib/file/tail/logfile.rb#26
class File::Tail::Logfile < ::File
  include ::File::Tail

  class << self
    # This method creates an File::Tail::Logfile object and
    # yields to it, and closes it, if a block is given, otherwise it just
    # returns it. The opts hash takes an option like
    # * <code>:backward => 10</code> to go backwards
    # * <code>:forward => 10</code> to go forwards
    # in the logfile for 10 lines at the start. The buffersize
    # for going backwards can be set with the
    # * <code>:bufsiz => 8192</code> option.
    # To define a callback, that will be called after a reopening occurs, use:
    # * <code>:after_reopen => lambda { |file| p file }</code>
    #
    # Every attribute of File::Tail can be set with a <code>:attributename =>
    # value</code> option.
    #
    # source://file-tail//lib/file/tail/logfile.rb#42
    def open(filename, opts = T.unsafe(nil), &block); end

    # Like open, but yields to every new line encountered in the logfile in
    # +block+.
    #
    # source://file-tail//lib/file/tail/logfile.rb#76
    def tail(filename, opts = T.unsafe(nil), &block); end
  end
end

# The ReopenException is raised internally if File::Tail
# gets suspicious something unusual has happend to
# the tailed file, e. g., it was rotated away. The exception
# is caught and an attempt to reopen it is made.
#
# source://file-tail//lib/file/tail.rb#32
class File::Tail::ReopenException < ::File::Tail::TailException
  # Creates an ReopenException object. The mode defaults to
  # <code>:bottom</code> which indicates that the file
  # should be tailed beginning from the end. <code>:top</code>
  # indicates, that it should be tailed from the beginning from the
  # start.
  #
  # @return [ReopenException] a new instance of ReopenException
  #
  # source://file-tail//lib/file/tail.rb#40
  def initialize(mode = T.unsafe(nil)); end

  # Returns the value of attribute mode.
  #
  # source://file-tail//lib/file/tail.rb#33
  def mode; end
end

# The ReturnException is raised and caught
# internally to implement "tail -10" behaviour.
#
# source://file-tail//lib/file/tail.rb#21
class File::Tail::ReturnException < ::File::Tail::TailException; end

# This is the base class of all exceptions that are raised
# in File::Tail.
#
# source://file-tail//lib/file/tail.rb#13
class File::Tail::TailException < ::Exception; end

# This class supervises activity on a tailed fail and collects newly read
# lines until the Tail::Group fetches and processes them.
#
# source://file-tail//lib/file/tail/tailer.rb#5
class File::Tail::Tailer < ::Thread
  # Return the thread local variable +id+ if it is defined.
  #
  # source://file-tail//lib/file/tail/tailer.rb#27
  def method_missing(id, *args, &block); end

  # Fetch all the pending lines from this Tailer and thereby remove them
  # from the Tailer's queue.
  #
  # source://file-tail//lib/file/tail/tailer.rb#14
  def pending_lines; end

  # True if there are any lines pending on this Tailer, false otherwise.
  #
  # @return [Boolean]
  #
  # source://file-tail//lib/file/tail/tailer.rb#8
  def pending_lines?; end

  # Return true if the thread local variable +id+ is defined or if this
  # object responds to the method +id+.
  #
  # @return [Boolean]
  #
  # source://file-tail//lib/file/tail/tailer.rb#22
  def respond_to?(id); end

  # Stop tailing this file and remove it from its File::Tail::Group.
  def stop; end
end

# File::Tail version
#
# source://file-tail//lib/file/tail/version.rb#3
File::Tail::VERSION = T.let(T.unsafe(nil), String)

# source://file-tail//lib/file/tail/version.rb#4
File::Tail::VERSION_ARRAY = T.let(T.unsafe(nil), Array)

# source://file-tail//lib/file/tail/version.rb#7
File::Tail::VERSION_BUILD = T.let(T.unsafe(nil), Integer)

# source://file-tail//lib/file/tail/version.rb#5
File::Tail::VERSION_MAJOR = T.let(T.unsafe(nil), Integer)

# source://file-tail//lib/file/tail/version.rb#6
File::Tail::VERSION_MINOR = T.let(T.unsafe(nil), Integer)
