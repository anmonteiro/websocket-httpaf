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

module Stream = struct
  type +'a io = 'a Async_kernel.Deferred.t
  type 'a t = 'a Async_kernel.Pipe.Reader.t

  let create () =
    let open Async_kernel in
    let reader, writer = Pipe.create () in
    let push_to_pipe = function
      | Some v ->
        Pipe.pushback writer >>> fun () ->
        if not (Pipe.is_closed writer) then
          Pipe.write writer v |> ignore
      | None -> Pipe.close writer

    in
    reader, push_to_pipe

  let iter_s f t = Async_kernel.Pipe.iter t ~f
end

module Io_unix = struct
  type +'a io = 'a Async_kernel.Deferred.t
  type file_descr = Async_unix.Fd.t

  type input_channel = Async_unix.Reader.t

  type output_channel = Async_unix.Writer.t

  let input_channel_of_fd fd =
    Async_unix.Reader.of_in_channel
    (fd |> Async_unix.Fd.file_descr_exn |> Core.Unix.in_channel_of_descr)
    (Async_unix.Fd.kind fd)

  let output_channel_of_fd fd =
    Async_unix.Writer.of_out_channel
    (fd |> Async_unix.Fd.file_descr_exn |> Core.Unix.out_channel_of_descr)
    (Async_unix.Fd.kind fd)

end

include Websocket_httpaf.Make (Websocket_async_io) (Stream) (Io_unix)
