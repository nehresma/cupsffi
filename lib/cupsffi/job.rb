class CupsJob
  attr_reader :id, :printer

  def initialize(id, printer = nil)
    @id = Integer(id)
    @printer = printer unless printer.nil?
  end

  def cancel(printer = nil)
    raise "cancel parameter must be a CupsPrinter or String" unless printer.nil? || [CupsPrinter, String].include?(printer.class)
    p = printer || @printer
    r = CupsFFI::cupsCancelJob(p.kind_of?(String) ? p : p.name, @id)
    raise CupsFFI::cupsLastErrorString() if r == 0
  end

  def status(printer = nil)
    raise "status parameter must be a CupsPrinter or String" unless printer.nil? || [CupsPrinter, String].include?(printer.class)
    pointer = FFI::MemoryPointer.new :pointer
    p = printer || @printer
    job_count = CupsFFI::cupsGetJobs(pointer, p.kind_of?(String) ? p : p.name, 0, CupsFFI::CUPS_WHICHJOBS_ALL)

    free_jobs = lambda do
      CupsFFI::cupsFreeJobs(job_count, pointer.get_pointer(0))
    end

    job_count.times do |i|
      job = CupsFFI::CupsJobS.new(pointer.get_pointer(0) + (CupsFFI::CupsJobS.size * i))
      if job[:id] == @id then
        state = job[:state]
        free_jobs.call
        return state
      end
    end

    free_jobs.call
    raise "Job not found on printer"
  end
end
