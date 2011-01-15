require 'ffi'

module CupsFFI
  extend FFI::Library
  ffi_lib 'cups'

  class CupsOptionS < FFI::Struct
    layout  :name, :string,
            :value, :string
  end

  class CupsDestS < FFI::Struct
    layout  :name, :string,
            :instance, :string,
            :is_default, :int,
            :num_options, :int,
            :options, :pointer  # pointer type is CupsOptionS
  end

  attach_function 'cupsGetDests', [ :pointer ], :int
  attach_function 'cupsFreeDests', [ :int, :pointer ], :void
end
