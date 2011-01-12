class Cups
  def self.get_printer_names
    p = FFI::MemoryPointer.new :pointer
    dest_count = CupsFFI::cupsGetDests(p)
    ary = []
    dest_count.times do |i|
      d = CupsFFI::CupsDestS.new(p.get_pointer(i))
      ary.push(d[:name])
    end
    CupsFFI::cupsFreeDests(dest_count, p)
    ary
  end

  def self.get_printer_options(printer_name)
    p = FFI::MemoryPointer.new :pointer
    dest_count = CupsFFI::cupsGetDests(p)
    ary = []
    dest_count.times do |i|
      dest = CupsFFI::CupsDestS.new(p.get_pointer(i))
      next unless dest[:name] == printer_name
      dest[:num_options].times do |j|
        options = CupsFFI::CupsOptionS.new(dest[:options] + (CupsFFI::CupsOptionS.size * j))
        ary.push({:name => options[:name], :value => options[:value]})
      end
    end
    CupsFFI::cupsFreeDests(dest_count, p)
    ary
  end
end
