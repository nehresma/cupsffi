class Printer
  attr_reader :name

  def initialize(name)
    raise "Printer not found" unless Printer.get_all_printer_names.include? name
    @name = name
  end

  def self.get_all_printer_names
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

  def attributes
    p = FFI::MemoryPointer.new :pointer
    dest_count = CupsFFI::cupsGetDests(p)
    hash = {}
    dest_count.times do |i|
      dest = CupsFFI::CupsDestS.new(p.get_pointer(0) + (CupsFFI::CupsDestS.size * i))
      next unless dest[:name] == @name
      dest[:num_options].times do |j|
        options = CupsFFI::CupsOptionS.new(dest[:options] + (CupsFFI::CupsOptionS.size * j))
        hash[options[:name].dup] = options[:value].dup
      end
    end
    CupsFFI::cupsFreeDests(dest_count, p.get_pointer(0))
    hash
  end

  def state
    o = attributes

    {
      :state =>
        case o['printer-state']
          when "3" then :idle
          when "4" then :printing
          when "5" then :stopped
          else :unknown
        end,
      :reasons => o['printer-state-reasons'].split(/,/)
    }
  end

  def print_file(file_name, options = {})
    raise "File not found: #{file_name}" unless File.exists? file_name

    options_pointer = nil
    num_options = 0
    unless options.empty?
      options_pointer = FFI::MemoryPointer.new :pointer
      options.map do |key,value|
        num_options = CupsFFI::cupsAddOption(key.to_s, value.to_s, num_options, options_pointer)
      end
    end

    job_id = CupsFFI::cupsPrintFile(@name, file_name, file_name, num_options, options_pointer.get_pointer(0))

    if job_id == 0
      last_error = CupsFFI::cupsLastErrorString()
      CupsFFI::cupsFreeOptions(num_options, options_pointer.get_pointer(0)) unless options_pointer.nil?
      raise last_error
    end

    CupsFFI::cupsFreeOptions(num_options, options_pointer.get_pointer(0)) unless options_pointer.nil?
    Job.new(job_id, self)
  end

  def print_data(data, mime_type, options = {})
    options_pointer = nil
    num_options = 0
    unless options.empty?
      options_pointer = FFI::MemoryPointer.new :pointer
      options.map do |key,value|
        num_options = CupsFFI::cupsAddOption(key.to_s, value.to_s, num_options, options_pointer)
      end
    end

    job_id = CupsFFI::cupsCreateJob(CupsFFI::CUPS_HTTP_DEFAULT, @name, 'data job', num_options, options_pointer)
    if job_id == 0
      last_error = CupsFFI::cupsLastErrorString()
      CupsFFI::cupsFreeOptions(num_options, options_pointer.get_pointer(0)) unless options_pointer.nil?
      raise last_error
    end

    http_status = CupsFFI::cupsStartDocument(CupsFFI::CUPS_HTTP_DEFAULT, @name,
                                             job_id, 'my doc', mime_type, 1)

    http_status = CupsFFI::cupsWriteRequestData(CupsFFI::CUPS_HTTP_DEFAULT, data, data.length)

    ipp_status = CupsFFI::cupsFinishDocument(CupsFFI::CUPS_HTTP_DEFAULT, @name)

    unless ipp_status == CupsFFI::IppStatus.find(:ipp_ok)
      CupsFFI::cupsFreeOptions(num_options, options_pointer.get_pointer(0)) unless options_pointer.nil?
      raise ipp_status.to_s
    end

    CupsFFI::cupsFreeOptions(num_options, options_pointer.get_pointer(0)) unless options_pointer.nil?
    Job.new(job_id, self)
  end

  def cancel_all_jobs
    r = CupsFFI::cupsCancelJob(@name, CupsFFI::CUPS_JOBID_ALL)
    raise CupsFFI::cupsLastErrorString() if r == 0
  end

end
