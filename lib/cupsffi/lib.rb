require 'ffi'

module CupsFFI
  extend FFI::Library
  ffi_lib 'cups'

  ### cups.h API

  CUPS_JOBID_ALL = -1
  CUPS_WHICHJOBS_ALL = -1
  CUPS_WHICHJOBS_ACTIVE = 0
  CUPS_WHICHJOBS_COMPLETED = 1
  CUPS_HTTP_DEFAULT = nil

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

  IppJState = enum [:pending, 3,
                    :held,
                    :processing,
                    :stopped,
                    :canceled,
                    :aborted,
                    :completed]

  class CupsJobS < FFI::Struct
    layout  :id, :int,
            :dest, :string,
            :title, :string,
            :user, :string,
            :format, :string,
            :state, IppJState,
            :size, :int,
            :priority, :int,
            :completed_time, :long,
            :creation_time, :long,
            :processing_time, :long
  end

  HttpStatus = enum [:http_error, -1,
                     :http_continue, 100,
                     :http_switching_protocols,
                     :http_ok, 200,
                     :http_created,
                     :http_accepted,
                     :http_not_authoritative,
                     :http_no_content,
                     :http_reset_content,
                     :http_partial_content,
                     :http_multiple_choices, 300,
                     :http_moved_permanently,
                     :http_moved_temporarily,
                     :http_see_other,
                     :http_not_modified,
                     :http_use_proxy,
                     :http_bad_request, 400,
                     :http_unauthorized,
                     :http_payment_required,
                     :http_forbidden,
                     :http_not_found,
                     :http_method_not_allowed,
                     :http_not_acceptable,
                     :http_proxy_authentication,
                     :http_request_timeout,
                     :http_conflict,
                     :http_gone,
                     :http_length_required,
                     :http_precondition,
                     :http_request_too_large,
                     :http_uri_too_long,
                     :http_unsupported_mediatype,
                     :http_requested_range,
                     :http_expectation_failed,
                     :http_upgrade_required, 426,
                     :http_server_error, 500,
                     :http_not_implemented,
                     :http_bad_gateway,
                     :http_service_unavailable,
                     :http_gateway_timeout,
                     :http_not_supported,
                     :http_authorization_canceled, 1000]

  IppStatus = enum [:ipp_ok, 0,
                    :ipp_ok_subst,
                    :ipp_ok_conflict,
                    :ipp_ok_ignored_subscriptions,
                    :ipp_ok_ignored_notifications,
                    :ipp_ok_too_many_events,
                    :ipp_ok_but_cancel_subscription,
                    :ipp_ok_events_complete,
                    :ipp_redirection_other_site, 512,
                    :cups_see_other, 640,
                    :ipp_bad_request, 1024,
                    :ipp_forbidden,
                    :ipp_not_authenticated,
                    :ipp_not_authorized,
                    :ipp_not_possible,
                    :ipp_timeout,
                    :ipp_not_found,
                    :ipp_gone,
                    :ipp_request_entity,
                    :ipp_request_value,
                    :ipp_document_format,
                    :ipp_attributes,
                    :ipp_uri_scheme,
                    :ipp_charset,
                    :ipp_conflict,
                    :ipp_compression_not_supported,
                    :ipp_compression_error,
                    :ipp_document_format_error,
                    :ipp_document_access_error,
                    :ipp_attributes_not_settable,
                    :ipp_ignored_all_subscriptions,
                    :ipp_too_many_subscriptions,
                    :ipp_ignored_all_notifications,
                    :ipp_print_support_file_not_found,
                    :ipp_internal_error, 1280,
                    :ipp_operation_not_supported,
                    :ipp_service_unavailable,
                    :ipp_version_not_supported,
                    :ipp_device_error,
                    :ipp_temporary_error,
                    :ipp_not_accepting,
                    :ipp_printer_busy,
                    :ipp_error_job_canceled,
                    :ipp_multiple_jobs_not_supported,
                    :ipp_printer_is_deactivated
                  ]





  attach_function 'cupsGetDests', [ :pointer ], :int

  # :int is the number of CupsDestS structs to free
  # :pointer is the first one
  attach_function 'cupsFreeDests', [ :int, :pointer ], :void

  # Parameters:
  #  - printer name
  #  - file name
  #  - job title
  #  - number of options
  #  - a pointer to a CupsOptionS struct
  # Returns
  #  - job number or 0 on error
  attach_function 'cupsPrintFile', [ :string, :string, :string, :int, :pointer ], :int

  attach_function 'cupsLastErrorString', [], :string

  # Parameters
  #  - printer name
  #  - job id
  attach_function 'cupsCancelJob', [:string, :int], :void

  # Parameters
  #  - pointer to struct CupsJobS to populate
  #  - printer name
  #  - myjobs (0 == all users, 1 == mine)
  #  - whichjobs (CUPS_WHICHJOBS_ALL, CUPS_WHICHJOBS_ACTIVE, or CUPS_WHICHJOBS_COMPLETED)
  # Returns:
  #  - number of jobs
  attach_function 'cupsGetJobs', [:pointer, :string, :int, :int], :int

  # Parameters
  #  - number of jobs
  #  - pointer to the first CupsJobS to free
  attach_function 'cupsFreeJobs', [:int, :pointer ], :void

  # Parameters
  #  - pointer to http connection to server or CUPS_HTTP_DEFAULT
  #  - printer name
  #  - title of job
  #  - number of options
  #  - pointer to a CupsOptionS struct
  # Returns
  #  - job number or 0 on error
  attach_function 'cupsCreateJob', [:pointer, :string, :string, :int, :pointer], :int

  # Parameters
  #  - pointer to http connection to server or CUPS_HTTP_DEFAULT
  #  - printer name
  #  - job id
  #  - name of document
  #  - mime type format
  #  - last document (1 for last document in job, 0 otherwise)
  # Returns
  #  - HttpStatus
  attach_function 'cupsStartDocument', [:pointer, :string, :int, :string, :string, :int], HttpStatus

  # Parameters
  #  - pointer to http connection to server or CUPS_HTTP_DEFAULT
  #  - data in a character string
  #  - length of data
  # Returns
  #  - HttpStatus
  attach_function 'cupsWriteRequestData', [:pointer, :string, :size_t], HttpStatus

  # Parameters
  #  - pointer to http connection to server or CUPS_HTTP_DEFAULT
  #  - printer name
  # Returns
  #  - IppStatus
  attach_function 'cupsFinishDocument', [:pointer, :string], IppStatus

  # Parameters
  #  - printer name
  # Returns
  #  - filename for PPD file
  attach_function 'cupsGetPPD', [:string], :string



  ### ppd.h API
  PPDCS = enum [:ppd_cs_cmyk, -4,
                :ppd_cs_cmy,
                :ppd_cs_gray, 1,
                :ppd_cs_rgb, 3,
                :ppd_cs_rgbk,
                :ppd_cs_n]

  class PPDFileS < FFI::ManagedStruct
    layout  :language_level, :int,
            :color_device, :int,
            :variable_sizes, :int,
            :accurate_screens, :int,
            :contone_only, :int,
            :landscape, :int,
            :model_number, :int,
            :manual_copies, :int,
            :throughput, :int,
            :colorspace, PPDCS,
            :patches, :string,
            :num_emulations, :int,
            :emulations, :pointer,
            :jcl_begin, :string,
            :jcl_ps, :string,
            :jcl_end, :string,
            :lang_encoding, :string,
            :lang_version, :string,
            :modelname, :string,
            :ttrasterizer, :string,
            :manufacturer, :string,
            :product, :string,
            :nickname, :string,
            :short_nickname, :string,
            :num_groups, :int,
            :groups, :pointer,
            :num_sizes, :int,
            :sizes, :pointer,
            :custom_min, [:float, 2],
            :custom_max, [:float, 2],
            :custom_margins, [:float, 4],
            :num_consts, :int,
            :consts, :pointer,
            :num_fonts, :int,
            :fonts, :pointer, # **char
            :num_profiles, :int,
            :profiles, :pointer,
            :num_filters, :int,
            :filters, :pointer, # **char
            :flip_duplex, :int,
            :protocols, :string,
            :pcfilename, :string,
            :num_attrs, :int,
            :cur_attr, :int,
            :attrs, :pointer,
            :sorted_attrs, :pointer,
            :options, :pointer,
            :coptions, :pointer,
            :marked, :pointer,
            :cups_uiconstraints, :pointer

    def self.release(ptr)
      CupsFFI::ppdClose(ptr)
    end
  end

  # Parameters
  #  - filename for PPD file
  # Returns
  #  - pointer to PPDFileS struct
  attach_function 'ppdOpenFile', [:string], :pointer

  # Parameters
  #  - pointer to PPDFileS struct
  attach_function 'ppdClose', [:pointer], :void
end
