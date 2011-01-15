class Cups
  def self.get_printer_names
    p = FFI::MemoryPointer.new :pointer
    dest_count = CupsFFI::cupsGetDests(p)
    ary = []
    dest_count.times do |i|
      d = CupsFFI::CupsDestS.new(p.get_pointer(0) + (CupsFFI::CupsDestS.size * i))
      ary.push(d[:name].dup)
    end
    CupsFFI::cupsFreeDests(dest_count, p.get_pointer(0))
    ary
  end

  def self.get_printer_options(printer_name)
    p = FFI::MemoryPointer.new :pointer
    dest_count = CupsFFI::cupsGetDests(p)
    hash = {}
    dest_count.times do |i|
      dest = CupsFFI::CupsDestS.new(p.get_pointer(0) + (CupsFFI::CupsDestS.size * i))
      next unless dest[:name] == printer_name
      dest[:num_options].times do |j|
        options = CupsFFI::CupsOptionS.new(dest[:options] + (CupsFFI::CupsOptionS.size * j))
        hash[options[:name].dup] = options[:value].dup
      end
    end
    CupsFFI::cupsFreeDests(dest_count, p.get_pointer(0))
    hash
  end
end
