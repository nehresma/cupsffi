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

class CupsPrinter
  attr_reader :name, :connection

  def self.get_connection(args = {})
    hostname = args[:hostname]
    port     = args[:port] || 631

    if hostname.nil?
      return CupsFFI::CUPS_HTTP_DEFAULT
    else
      connection = CupsFFI::httpConnectEncrypt(hostname, port.to_i, CupsFFI::cupsEncryption())
      raise "Printserver at #{hostname}:#{port} not available" if connection.null?

      return connection
    end
  end

  def self.walk_attributes(connection)
    p = FFI::MemoryPointer.new :pointer
    dest_count = CupsFFI::cupsGetDests2(connection, p)
    dest_count.times do |i|
      dest = CupsFFI::CupsDestS.new(p.get_pointer(0) + (CupsFFI::CupsDestS.size * i))
      yield dest
    end
    CupsFFI::cupsFreeDests(dest_count, p.get_pointer(0))
  end

  def self.walk_sub_attributes(dest)
    dest[:num_options].times do |j|
      options = CupsFFI::CupsOptionS.new(dest[:options] + (CupsFFI::CupsOptionS.size * j))
      yield options
    end
  end

  def self.release_connection(connection)
    CupsFFI::httpClose(connection)
  end

  def initialize(name, args = {})
    raise "Printer not found" unless CupsPrinter.get_all_printer_names(args).include? name
    @name = name
    @connection = CupsPrinter.get_connection(args)
  end

  def close
    CupsPrinter.release_connection(@connection)
  end

  def self.get_all_printer_names(args = {})
    connection = get_connection(args)
    ary = []
    walk_attributes(connection) do |dest|
      ary.push(dest[:name].dup)
    end
    release_connection(connection)
    ary
  end

  def self.get_all_printer_attrs(args = {})
    connection = get_connection(args)
    hash = {}
    walk_attributes(connection) do |dest|
      pname = dest[:name].dup
      hash[pname] ||= {}
      walk_sub_attributes(dest) do |options|
        hash[pname][options[:name].dup] = options[:value].dup
      end
    end
    release_connection(connection)
    hash
  end

  def attributes
    hash = {}
    CupsPrinter.walk_attributes(@connection) do |dest|
      next unless dest[:name] == @name
      CupsPrinter.walk_sub_attributes(dest) do |options|
        hash[options[:name].dup] = options[:value].dup
      end
    end
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
      validate_options(options)
      options_pointer = FFI::MemoryPointer.new :pointer
      options.map do |key,value|
        num_options = CupsFFI::cupsAddOption(key.to_s, value.to_s, num_options, options_pointer)
      end
      options_pointer = options_pointer.get_pointer(0)
    end

    job_id = CupsFFI::cupsPrintFile2(@connection, @name, file_name, file_name, num_options, options_pointer)

    if job_id == 0
      last_error = CupsFFI::cupsLastErrorString()
      CupsFFI::cupsFreeOptions(num_options, options_pointer) unless options_pointer.nil?
      raise last_error
    end

    CupsFFI::cupsFreeOptions(num_options, options_pointer) unless options_pointer.nil?
    CupsJob.new(job_id, self)
  end

  def print_data(data, mime_type, options = {})
    options_pointer = nil
    num_options = 0
    unless options.empty?
      validate_options(options)
      options_pointer = FFI::MemoryPointer.new :pointer
      options.map do |key,value|
        num_options = CupsFFI::cupsAddOption(key.to_s, value.to_s, num_options, options_pointer)
      end
      options_pointer = options_pointer.get_pointer(0)
    end

    job_id = CupsFFI::cupsCreateJob(@connection, @name, 'data job', num_options, options_pointer)
    if job_id == 0
      last_error = CupsFFI::cupsLastErrorString()
      CupsFFI::cupsFreeOptions(num_options, options_pointer) unless options_pointer.nil?
      raise last_error
    end

    http_status = CupsFFI::cupsStartDocument(@connection, @name,
                                             job_id, 'my doc', mime_type, 1)

    http_status = CupsFFI::cupsWriteRequestData(@connection, data, data.length)

    ipp_status = CupsFFI::cupsFinishDocument(@connection, @name)

    unless ipp_status == :ipp_ok
      CupsFFI::cupsFreeOptions(num_options, options_pointer) unless options_pointer.nil?
      raise ipp_status.to_s
    end

    CupsFFI::cupsFreeOptions(num_options, options_pointer) unless options_pointer.nil?
    CupsJob.new(job_id, self)
  end

  def cancel_all_jobs
    r = CupsFFI::cupsCancelJob2(@connection, @name, CupsFFI::CUPS_JOBID_ALL)
    raise CupsFFI::cupsLastErrorString() if r == 0
  end


  private
  def validate_options(options)
    ppd = CupsPPD.new(@name, @connection)

    # Build a hash of the ppd options for quick lookup
    ppd_options = {}
    ppd.options.each do |ppd_option|
      ppd_options[ppd_option[:keyword]] = ppd_option
    end

    # Examine each input option to make sure that both the key and value are
    # found in the ppd options.
    options.each do |key,value|
      key_string = key.to_s
      # Accept common CUPS options
      next if ['copies'].include?(key_string)

      raise "Invalid option #{key} for printer #{@name}" if ppd_options[key_string].nil?
      choices = ppd_options[key_string][:choices].map{|c| c[:choice]}
      # Treat 'Custom.WIDTHxHEIGHT' as just 'Custom'
      base_value = (value =~ /^Custom\./ && %w{PageRegion PageSize}.include?(key_string)) ? 'Custom' : value
      raise "Invalid value #{value} for option #{key_string}" unless choices.include?(base_value)
    end
  end
end
