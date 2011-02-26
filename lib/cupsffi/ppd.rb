class CupsPPD
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

  def options
    options = []
    option_pointer = CupsFFI::ppdFirstOption(@pointer)
    while !option_pointer.null?
      option = CupsFFI::PPDOptionS.new(option_pointer)
      choices = []
      option[:num_choices].times do |i|
        choice = CupsFFI::PPDChoiceS.new(option[:choices] + (CupsFFI::PPDChoiceS.size * i))
        choices.push({
          :text => String.new(choice[:text]),
          :choice => String.new(choice[:choice])
        })
      end
      options.push({
        :keyword => String.new(option[:keyword]),
        :default_choice => String.new(option[:defchoice]),
        :text => String.new(option[:text]),
        :ui => String.new(option[:ui].to_s),
        :section => String.new(option[:section].to_s),
        :order => option[:order],
        :choices => choices
      })

      option_pointer = CupsFFI::ppdNextOption(@pointer)
    end
    options
  end
end
