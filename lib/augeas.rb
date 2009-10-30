##
#  augeas.rb: Ruby wrapper for augeas
#
#  Copyright (C) 2008 Red Hat Inc.
#
#  This library is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public
#  License as published by the Free Software Foundation; either
#  version 2.1 of the License, or (at your option) any later version.
#
#  This library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#  Lesser General Public License for more details.
#
#  You should have received a copy of the GNU Lesser General Public
#  License along with this library; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307  USA
#
# Author: Bryan Kearney <bkearney@redhat.com>
##

require "augeas/augeaslib"

#
# Wrapper class for the augeas[http://augeas.net] library.
# For better documentation on the method calls, see
# http://www.augeas.net/docs/api.html. In general, a
# method called 'foo' in this class corresponds to
# a function called 'aug_foo' in that libary.
#
class Augeas

    private_class_method :new

    # internal error class
    class Error < RuntimeError; end

    # Flags to use
    NONE = 0

    # Keep the original file with a .augsave extension
    SAVE_BACKUP = (1 << 0)

    # Save changes into a file with extension .augnew, and do not overwrite the
    # original file. Takes precedence over AUG_SAVE_BACKUP
    SAVE_NEWFILE = (1 << 1)

    # Typecheck lenses; since it can be very expensive it is not done by
    # default
    TYPE_CHECK = (1 << 2);

    # Do not use the builtin load path for modules
    NO_STDINC = (1 << 3);

    # Make save a no-op process, just record what would have changed
    SAVE_NOOP = (1 << 4);

    # Do not load the tree from AUG_INIT
    NO_LOAD = (1 << 5);

    # Do not load the modules marked as autoload
    NO_MODL_AUTOLOAD = (1 << 6);

    # Initializes the Augeas wrapper class with an pointer
    # to the augeas library
    def initialize(augPtr = nil)
        @aug = augPtr
    end

    # Create a new Augeas instance and return it.
    #
    # Use +root+ as the filesystem root. If +root+ is +nil+, use the value
    # of the environment variable +AUGEAS_ROOT+. If that doesn't exist
    # either, use "/".
    #
    # +loadpath+ is a colon-spearated list of directories that modules
    # should be searched in. This is in addition to the standard load path
    # and the directories in +AUGEAS_LENS_LIB+
    #
    # +flags+ is a bitmask (see <tt>enum aug_flags</tt>)
    #
    # When a block is given, the Augeas instance is passed as the only
    # argument into the block and closed when the block exits. In that
    # case, the return value of the block is the return value of
    # +open+. With no block, the Augeas instance is returned.
    def Augeas.open(root = nil, loadpath = nil, flags = NONE, &block)
        @aug = AugeasLib.aug_init(root, loadpath, flags)
        inst = new(@aug)
        if block_given?
            begin
                rv = yield inst
                return rv
            ensure
                inst.close()
            end
        else
            return inst
        end
    end

    # Clear the +path+, i.e. make its value +nil+
    def clear(path)
        set(path, nil)
    end

    # Clear all transforms under <tt>/augeas/load</tt>. If +load+
    # is called right after this, there will be no files
    # under +/files+
    def clear_transforms
        rm("/augeas/load/*")
    end

    # Add a transform under <tt>/augeas/load</tt>
    #
    # The HASH can contain the following entries
    # * <tt>:lens</tt> - the name of the lens to use
    # * <tt>:name</tt> - a unique name; use the module name of the LENS when omitted
    # * <tt>:incl</tt> - a list of glob patterns for the files to transform
    # * <tt>:excl</tt> - a list of the glob patterns to remove from the list that matches <tt>:INCL</tt>
    def transform(hash)
        lens = hash[:lens]
        name = hash[:name]
        incl = hash[:incl]
        excl = hash[:excl] || ""
        raise ArgumentError, "No lens specified" unless lens
        raise ArgumentError, "No files to include" unless incl
        name = lens.split(".")[0].sub("@", "") unless name
        incl = [ incl ] unless incl.is_a?(Array)
        excl = [ excl ] unless incl.is_a?(Array)

        xfm = "/augeas/load/#{name}/"
        set(xfm + "lens", lens)
        incl.each { |inc| set(xfm + "incl[last()+1]", inc) }
        excl.each { |exc| set(xfm + "excl[last()+1]", exc) }
    end

    # The same as +save+, but raises <tt>Augeas::Error</tt> if saving fails
    def save!
        raise Augeas::Error unless self.save
    end

    # Saves the contents of the tree to disk, returns True if the
    def save
        check()
        rv = AugeasLib.aug_save(@aug)
        return rv == 0
    end

    # The same as +load+, but raises <tt>Augeas::Error</tt> if loading fails
    def load!
        raise Augeas::Error unless self.load
    end

    # Loads the lenses as set up in /augeas/load
    def load
        check()
        rv = AugeasLib.aug_load(@aug)
        return rv == 0
    end

    # Makes the value of +path+ be +value+
    def set(path, value)
        check()
        rv = AugeasLib.aug_set(@aug, path, value)
        return rv == 0
    end

    # The same as +set+, but raises <tt>Augeas::Error</tt> if loading fails
    def set!(path, value)
        raise Augeas::Error unless self.set(path, value)
    end

    # Inserts a new node at +paht+ with the name +label+. If +before+
    # is provided, it controls whether to insert before or after the
    # +path+ (default is after).
    def insert(path, label, before = false)
        int intbefore = before ? 1 : 0;
        check()
        rv = AugeasLib.aug_insert(@aug, path, value, intbefore)
    end

    # Define a variable +name+ whose value is the result of evaluating
    # +expression+, which must be non-NULL and evaluate to a nodeset.
    def defnode(name, expression, value)
        check()
        rv = AugeasLib.aug_defnode(@aug, name, expression, value, nil)
        rv < 0 ? false : rv
    end

    # See +defnode+
    def define_node(name, expression, value)
        defnode(name, expression, value)
    end

    # Define a variable +name+ whose value is the result of evaluating
    # +expression+
    def defvar(name, expression)
        check()
        rv = AugeasLib.aug_defvar(@aug, name, expression)
        return rv >= 0
    end

    # See +defvar+
    def define_variable(name, expression)
        defvar(name, expression)
    end

    # Move the tree at +source+ to +dest+
    def mv(source, dest)
        check()
        rv = AugeasLib.aug_mv(@aug, source, dest)
        rv
    end

    # See +mv+
    def move(source, dest)
        mv(source, dest)
    end

    # Returns the value at +path+ or nil if none is found
    def get(path)
        check()
        ptr = FFI::MemoryPointer.new(:pointer, 1)
        AugeasLib.aug_get(@aug, path, ptr)
        strPtr = ptr.read_pointer()
        return strPtr.null? ? nil : strPtr.read_string()
    end

    # Returns true if the is at least one node or value at
    # +path+
    def exists(path)
        check();
        rv = AugeasLib.aug_get(@aug, path, nil);
        return rv == 1;
    end

    # Returns all the nodes which match the provided expression.
    # If there is no mathc, a <tt>SystemCallError</tt> is returned
    def match(path)
        check()
        ptr = FFI::MemoryPointer.new(:pointer, 1)
        len = AugeasLib.aug_match(@aug, path, ptr)
        if (len < 0)
            raise SystemCallError.new("Matching path expression '#{path}' failed")
        else
            strPtr = ptr.read_pointer()
            strPtr.null? ? [] : strPtr.get_array_of_string(0, len).compact
        end
    end

    # Removes the nodes at +path+
    def rm(path)
        check()
        rv = AugeasLib.aug_rm(@aug, path)
        rv
    end

    # See +rm+
    def remove(path)
        self.rm(path)
    end

    # Closes the connection to the Augeas Library. Subsequent calls to
    # this object will throw an exception
    def close()
       check()
       AugeasLib.aug_close(@aug)
       @aug = nil ;
    end

    private
    # Ensure close() has not been called
    def check()
        raise SystemCallError.new("Augeas pointer is nil") if @aug.nil?
    end
end
