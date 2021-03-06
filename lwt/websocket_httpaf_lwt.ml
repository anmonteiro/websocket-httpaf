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
  type +'a io = 'a Lwt.t
  include Lwt_stream
end

module Io_unix = struct
  type +'a io = 'a Lwt.t
  type file_descr = Lwt_unix.file_descr

  type input_channel = Lwt_io.input_channel

  type output_channel = Lwt_io.output_channel

  let input_channel_of_fd fd = Lwt_io.of_fd ~mode:Input fd

  let output_channel_of_fd fd = Lwt_io.of_fd ~mode:Output fd

end

include Websocket_httpaf.Make (Websocket_lwt_io) (Stream) (Io_unix)

