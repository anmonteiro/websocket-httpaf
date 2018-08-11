(*
 * Copyright (c) 2012-2016 Vincent Bernardoff <vb@luminar.eu.org>
 * Copyright (c) 2018-present Antonio Nuno Monteiro <anmonteiro@gmail.com>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 *)

(*
 * Adapted from:
 * https://github.com/vbmithr/ocaml-websocket/blob/master/lwt/websocket_cohttp_lwt.ml
 *)

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
                        and type output_channel = Io.oc) = struct
  type +'a io = 'a Io.t
  type file_descr = Io_unix.file_descr

  include Websocket

  module Websocket_Io = Websocket.IO(Io)

  let send_frames stream oc =
    let buf = Buffer.create 128 in
    let send_frame fr =
      Buffer.clear buf;
      Websocket_Io.write_frame_to_buf ~mode:Server buf fr;
      Io.write oc @@ Buffer.contents buf
    in
    Stream.iter_s send_frame stream

  let read_frames ic oc handler_fn =
    let read_frame = Websocket_Io.make_read_frame ~mode:Server ic oc in
    let rec inner () =
      let open Io in
      read_frame () >>= fun frame ->
      Io.return (handler_fn frame) >>= inner
    in inner ()

  let upgrade_connection ?(headers=Httpaf.Headers.empty) reqd fd incoming_handler =
    let request = Httpaf.Reqd.request reqd in
    let request_body = Httpaf.Reqd.request_body reqd in
    let key = Httpaf.Headers.get_exn request.headers "sec-websocket-key" in
    let hash = key ^ Websocket.websocket_uuid |> Websocket.b64_encoded_sha1sum in
    let response_headers =
      Httpaf.Headers.add_list
        (Httpaf.Headers.of_list
           ["Upgrade", "websocket";
            "Connection", "Upgrade";
            "Sec-WebSocket-Accept", hash;
            "Transfer-Encoding", "unknown"])
        (Httpaf.Headers.to_list headers)
    in
    let resp =
      Httpaf.Response.create
        ~headers:response_headers
        `Switching_protocols
    in
    let frames_out_stream, frames_out_fn = Stream.create () in
    let upgrade_finished, notify_upgrade_finished = Io.wait () in

    let response_body =
      Httpaf.Reqd.respond_with_streaming ~wait_for_first_flush:false reqd resp in

    let rec on_read _ ~off:_  ~len:_  =
      Httpaf.Body.schedule_read request_body ~on_read ~on_eof
    and on_eof () =
      Httpaf.Body.flush response_body (fun () ->
          let oc = Io_unix.output_channel_of_fd fd in
          let ic = Io_unix.input_channel_of_fd fd in
          let _ = Io.join [
              (* input: data from the client is read from the input channel
               * of the tcp connection; pass it to handler function *)
              read_frames ic oc incoming_handler;
              (* output: data for the client is written to the output
               * channel of the tcp connection *)
              send_frames frames_out_stream oc;
            ] in
          Io.wakeup_later notify_upgrade_finished (resp, response_body, frames_out_fn))
    in
    Httpaf.Body.schedule_read request_body ~on_eof ~on_read;
    upgrade_finished
end
