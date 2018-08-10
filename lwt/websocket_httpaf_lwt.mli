include
  Websocket_httpaf_intf.Websocket_httpaf with type 'a io = 'a Lwt.t
                                          and type file_descr = Lwt_unix.file_descr
