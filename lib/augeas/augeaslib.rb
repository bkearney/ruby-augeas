require 'ffi'

# The actual FFI mappings for the augeas library. This module is
# hidden by the acutal Augeas class.
module AugeasLib
  # Setup the FFI Magic
  extend FFI::Library
  ffi_lib "libaugeas.so"

  # Standad API
  attach_function :aug_init, [:string, :string, :int], :pointer
  attach_function :aug_defvar, [:pointer, :string, :string], :int
  attach_function :aug_defnode, [:pointer, :string, :string, :string, :pointer], :int
  attach_function :aug_get, [:pointer, :string, :pointer], :int
  attach_function :aug_set, [:pointer, :string, :string], :int
  attach_function :aug_insert, [:pointer, :string, :string, :int], :int
  attach_function :aug_rm, [:pointer, :string], :int
  attach_function :aug_mv, [:pointer, :string, :string], :int
  attach_function :aug_match, [:pointer, :string, :pointer], :int
  attach_function :aug_save, [:pointer], :int
  attach_function :aug_load, [:pointer], :int
  attach_function :aug_close, [:pointer], :void

  # Error API may not be there in all instances
  begin
      attach_function :aug_error, [:pointer], :int
      attach_function :aug_error_message, [:pointer], :string
      attach_function :aug_error_minor_message, [:pointer], :string
      attach_function :aug_error_details, [:pointer], :string
  rescue FFI::NotFoundError
  end
end
