--
-- fstab.lua
--
-- $Id$
--
-- Lua 5.2 module providing a mingw-get setup hook for the MSYS fstab.
--
-- Written by Keith Marshall <keithmarshall@users.sourceforge.net>
-- Copyright (C) 2014, 2015, MinGW.org Project
--
--
-- Permission is hereby granted, free of charge, to any person obtaining a
-- copy of this software and associated documentation files (the "Software"),
-- to deal in the Software without restriction, including without limitation
-- the rights to use, copy, modify, merge, publish, distribute, sublicense,
-- and/or sell copies of the Software, and to permit persons to whom the
-- Software is furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included
-- in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
-- OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
-- THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
-- FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
-- DEALINGS IN THE SOFTWARE.
--
--
-- We begin by initializing a container, for construction of a Lua module
-- to encapsulate the content of this source file.
--
   local M = {}
--
-- mingw-get passes the MSYS installation root directory path,
-- in the $MSYS_SYSROOT environment variable; from this, we deduce
-- the path name for the working copy of the fstab file...
--
   local function syspath( varname )
--
--   ...using this local helper function to ensure that the path name
--   string, returned from the environment, is free from insignificant
--   trailing directory name separators, and that all internal sequences
--   of directory name separators are normalized to a single '/'.
--
     local pathname = string.gsub( os.getenv( varname ), "[/\\]+", "/" )
     return string.match( pathname, "(.*[^/])/*$" )
   end
   local sysroot = syspath( "MSYS_SYSROOT" )
   local mingw32_sysroot = syspath( "MINGW32_SYSROOT" )
   local fstab_file_name = sysroot .. "/etc/fstab"
--
-- The following may be adjusted, to control the layout of the mount
-- point mapping records, within the fstab file.
--
   local path_name_field_width, tab_width = 40, 8
--
-- Define a template, from which a sample fstab file for the current
-- MSYS installation may be generated, on invocation of this module's
-- "dump_sample" method...
--
   local fstab_sample =
   { '# /etc/fstab.sample -- sample mount table configuration for MSYS.',
     '',
     '# Lines with a "#" in column one are interpreted as comment lines;',
     '# with the exception of comments described as "magic", neither these',
     '# lines, nor any blank lines, are interpreted as configuration.',
     '',
     '# Comment lines which are described as "magic" should neither be',
     '# deleted, nor edited manually; ignoring this advice may cause your',
     '# MSYS installation to malfunction.',
     '',
     '# When running MSYS from a portable device, such as a USB thumb drive,',
     '# the following "magic" comment is used to track changes in host drive',
     '# letter assignment, so allowing MSYS-Portable start-up hooks to remap',
     '# mount table entries which refer to the relocated device:',
     '#',
     '# MSYSROOT=D:/PortableApps/MSYS/1.0',
     '',
     '# The mount table configuration follows below.  The line format is',
     '# simple: you specify the Win32 path, followed by one or more space or',
     '# tab delimiters, followed by the mount point name.  In a typical UNIX',
     '# installation, each mount point must exist as a named directory on a',
     '# physically accessible device, before it can actually be used as a',
     '# mount point.  For this implementation the "must exist" requirement',
     '# is not enforced; however, it will assist programs such as find, and',
     "# readline's tab completion if each does physically exist.",
     '',
     '# Win32_Path				Mount_Point',
     '#-------------------------------------	-----------',
     'c:/mingw					/mingw'
   }
--
-- ...and a further template for a working configuration.
--
   local fstab_basic =
   { '# /etc/fstab -- mount table configuration for MSYS.',
     '# Please refer to /etc/fstab.sample for explanatory annotation.',
     '',
     '# MSYS-Portable needs this "magic" comment:',
     '# MSYSROOT=D:/PortableApps/MSYS/1.0',
     '',
     '# Win32_Path				Mount_Point',
     '#-------------------------------------	-----------',
     'c:/mingw					/mingw'
   }
--
-- Define Lua regular expressions which may be used to identify
-- comment lines within the fstab file; (the first will match any
-- comment, while the second is specific to the "magic" comment,
-- as used by MSYS-Portable, to track changes in the allocation
-- of the drive identifier for the host device).
--
   local fstab_comment_line = "^#"
   local fstab_device_magic = "^(#%s*MSYSROOT=)(%S*)"
--
   local function map_root_device( assignment )
--
--   A function to update the "magic" comment, which records the
--   allocation of the MSYS-Portable host device.
--
     return string.gsub( assignment, fstab_device_magic, "%1" .. sysroot )
   end
--
-- Define a Lua regular expression which may be used to verify
-- that any fstab file record represents a well formed mount point
-- specification; it also incorporates capture fields, which may
-- be used to extract each of the path name and mount point
-- identification fields from the specification.
--
   local fstab_mount_specification = "^%s*(%S+)%s+(%S+)%s*$"
--
   local function is_mount_specification( line )
--
--   A function to verify any fstab file record against the
--   preceding regular expression, to confirm whether it does
--   represent a well formed mount point specification.
--
     return string.match( line, fstab_mount_specification )
   end
--
   local function get_mapped_path( specification )
--
--   A function to extract the associated path name field from
--   any well formed mount point specification record.
--
     return string.gsub( specification, fstab_mount_specification, "%1" )
   end
--
   local function get_mount_point( specification )
--
--   A function to extract the mount point identification field
--   from any well formed mount point specification record.
--
     return string.gsub( specification, fstab_mount_specification, "%2" )
   end
--
-- In the event that a mount table configuration has already been
-- specified for this installation, capture this into an internal
-- "as built" configuration table...
--
   local fstab_as_built = {}
   local fstab = io.open( fstab_file_name )
   if fstab
   then
--
--   ...reading the existing configuration file, line by line...
--
     for line in fstab:lines()
     do
--
--     ...identifying comment lines...
--
       if string.match( line, fstab_comment_line )
       then
--
--       ...and ignoring all such, except any "device magic" line...
--
	 if string.match( line, fstab_device_magic )
	 then
--
--         ...from which we retrieve, and subsequently update, the
--         configuration-specific "sysroot" identification.
--
	   sysroot = string.gsub( line, fstab_device_magic, "%2" )
	 end
--
--     Also identify mount point specification lines...
--
       elseif is_mount_specification( line )
       then
	 if string.match( get_mount_point( line ), "^/mingw$" )
	 then
--
--	   ...and preserve the user's pre-configured path assignment
--	   for the "/mingw" mount point, if any.
--
	   mingw32_sysroot = get_mapped_path( line )
--
	 else
--
--	   ...while, for all EXCEPT the "/mingw" mount point,
--	   simply record the configuration.
--
	   table.insert( fstab_as_built, line )
	 end
       end
     end
   end
--
--
   local function fstab_write_configuration( fstab, template, current )
--
--   A function to write an fstab configuration to a designated output
--   stream, based on a specified template, reproducing and encapsulating
--   any existing configuration which may also have been specified...
--
     local function fstab_writeln( line )
--
--     ...using this helper function to write line by line.
--
       fstab:write( line .. "\n" )
     end
--
     local function assign_mount_point( mapped_path, mount_point )
--
--     This helper function formats each mount point specification
--     into a neatly tabulated layout...
--
       local filled = string.len( mapped_path )
       repeat
	 mapped_path, filled = mapped_path .. "\t", filled + tab_width
       until filled >= path_name_field_width
--
--     ...to be written out, with one line per mount point.
--
       fstab_writeln( mapped_path .. mount_point )
     end
--
--   Process the template, line by line...
--
     for ref, line in next, template
     do
--     ...and for each comment, or blank line encountered...
--
       if string.match( line, "^#" ) or string.match( line, "^%s*$" )
       then
--	 ...simply reproduce it in the output stream, while taking
--	 care to update any "device magic" which it may incorporate,
--	 so that it fits the configuration of this installation.
--
	 fstab_writeln( map_root_device( line ) )
--
--     When we encounter a mount point specification line -- for
--     which each of the embedded templates should include exactly
--     one example...
--
       elseif is_mount_specification( line )
       then
--	 ...write out the specification for the "/mingw" mount
--	 point, as appropriate for this installation.
--
	 assign_mount_point( mingw32_sysroot, "/mingw" )
       end
     end
--
--   And finally...
--
     if current
     then
--     ...when inclusion of the current mount configuration has been
--     specified, we process each configuration record in turn...
--
       for ref, line in next, current
       do
--	 ...and write out its corresponding mount point specification,
--	 (noting that we have already excluded the "/mingw" mount point
--	 from the recorded configuration, but we have already written a
--	 specification record for it).
--
	 assign_mount_point( get_mapped_path( line ), get_mount_point( line ) )
       end
     end
   end
--
--
   function M.pathname( suffix )
--
--   An exported utility function, to facilitate identification of
--   the full MS-Windows path name for the "/etc/fstab" configuration
--   file, as appropriate to the current installation...
--
     if suffix
     then
--     ...appending any suffix which may have been specified, (e.g.
--     to specify a reference to the "/etc/fstab.sample" file)...
--
       return fstab_file_name .. suffix
     end
--
--   ...otherwise, specifying a reference to "/etc/fstab" itself.
--
     return fstab_file_name
   end
--
--
   function M.dump_sample( stream_file )
--
--   An exported utility function, providing a method for displaying,
--   or otherwise emitting suitable content for the "/etc/fstab.sample"
--   file, as directed by the embedded "fstab_sample" template...
--
     if not stream_file
     then
--     ...writing to "stdout", in the event that no other destination
--     has been specified.
--
       stream_file = io.stdout
     end
--
--   Regardless of output destination, we delegate output to this local
--   function, processing the integral sample file template, but we omit
--   the current mount table configuration.
--
     fstab_write_configuration( stream_file, fstab_sample )
   end
--
--
   function M.initialize( stream_file )
--
--   The primary initialization function, exported for use by mingw-get,
--   to write a working mount table configuration to the specified file
--   stream, which, unless otherwise specified...
--
     local default_stream_file = nil
     if not stream_file
     then
--     ...is to be directed to the default "/etc/fstab" file.
--
       default_stream_file = io.open( fstab_file_name, "w" )
       stream_file = default_stream_file
     end
--
--   Once again, regardless of how the output file has been identified,
--   provided the stream has been successfully assigned...
--
     if stream_file
     then
--     ...we delegate the actual output function to the local helper,
--     this time, processing the integral working file template, and we
--     include the record of the current mount table configuration.
--
       fstab_write_configuration( stream_file, fstab_basic, fstab_as_built )
     end
--
--   Finally, when updating the default "/etc/fstab" configuration,
--   via a locally opened output file stream...
--
     if default_stream_file
     then
--     ...we must now ensure that this output stream is closed.
--
       io.close( default_stream_file )
     end
   end
--
-- Since this source file is intended to be loaded as a Lua module, we
-- must ultimately return a reference handle for it.
--
   return M
--
-- $RCSfile$: end of file */
