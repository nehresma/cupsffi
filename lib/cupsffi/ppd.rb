class PPD
  def initialize(printer_name)
    @file = CupsFFI::cupsGetPPD(printer_name)
    raise "No PPD found for #{printer_name}" if @file.nil?

    @pointer = CupsFFI::ppdOpenFile(@file)
    raise "Unable to open PPD #{file}" if @pointer.null?

    @ppd_file_s = CupsFFI::PPDFileS.new(@pointer)
  end

  def close
    CupsFFI::ppdClose(@pointer)
    File.unlink(@file)
  end
end
