module type IO = sig
  include Cohttp.S.IO

  type 'a u

  val wait : unit -> 'a t * 'a u

  val join : unit t list -> unit t

  val wakeup_later : 'a u -> 'a -> unit
end

module type IO_unix = sig
  type +'a io
  type file_descr

  type input_channel

  type output_channel

  val input_channel_of_fd : file_descr -> input_channel

  val output_channel_of_fd : file_descr -> output_channel
end

(* Stream *)
module type Stream = sig
  type +'a io
  type 'a t

  val create : unit -> 'a t * ('a option -> unit)
  val iter_s : ('a -> unit io) -> 'a t -> unit io
end

module Make
    (Io : IO)
    (Stream: Stream with type 'a io = 'a Io.t)
    (Io_unix : IO_unix with type 'a io = 'a Io.t
                        and type input_channel = Io.ic
                        and type output_channel = Io.oc) :
  Websocket_httpaf_intf.Websocket_httpaf with type 'a io = 'a Io.t
                                          and type file_descr = Io_unix.file_descr
