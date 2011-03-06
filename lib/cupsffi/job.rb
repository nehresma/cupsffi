# The MIT License
#
# Copyright (c) 2011 Nathan Ehresman
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

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
