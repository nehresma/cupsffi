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

  def self.get_printer_state(printer_name)
    options = self.get_printer_options(printer_name)

    case options['printer-state']
      when "3" then :idle
      when "4" then :printing
      when "5" then :stopped
      else :unknown
    end
  end

  def self.cancel_job(printer_name, job_id)
    r = CupsFFI::cupsCancelJob(printer_name, job_id)

    raise CupsFFI::cupsLastErrorString() if r == 0
  end

  def self.cancel_all_jobs(printer_name)
    self.cancel_job(printer_name, CupsFFI::CUPS_JOBID_ALL)
  end

  def self.print_file(printer_name, file_name)
    job_id = CupsFFI::cupsPrintFile(printer_name, file_name, file_name, 0, nil)

    raise CupsFFI::cupsLastErrorString() if job_id == 0
    job_id
  end

  def self.get_job_status(printer_name, job_id)
    p = FFI::MemoryPointer.new :pointer
    job_count = CupsFFI::cupsGetJobs(p, printer_name, 0, CupsFFI::CUPS_WHICHJOBS_ALL)

    free_jobs = lambda do
      CupsFFI::cupsFreeJobs(job_count, p.get_pointer(0))
    end

    job_count.times do |i|
      job = CupsFFI::CupsJobS.new(p.get_pointer(0) + (CupsFFI::CupsJobS.size * i))
      if job[:id] == job_id then
        state = job[:state]
        free_jobs.call
        return state
      end
    end

    free_jobs.call
    raise "Job not found on printer"
  end

  def self.print_data(printer_name, data, mime_type)
    job_id = CupsFFI::cupsCreateJob(CupsFFI::CUPS_HTTP_DEFAULT, printer_name, 'data job', 0, nil)
    raise CupsFFI::cupsLastErrorString() if job_id == 0

    http_status = CupsFFI::cupsStartDocument(CupsFFI::CUPS_HTTP_DEFAULT, printer_name,
                                             job_id, 'my doc', mime_type, 1)

    http_status = CupsFFI::cupsWriteRequestData(CupsFFI::CUPS_HTTP_DEFAULT, data, data.length)

    ipp_status = CupsFFI::cupsFinishDocument(CupsFFI::CUPS_HTTP_DEFAULT, printer_name)

    raise ipp_status.to_s unless ipp_status == CupsFFI::IppStatus.find(:ipp_ok)

    job_id
  end
end
