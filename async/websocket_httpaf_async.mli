include
  Websocket_httpaf_intf.Websocket_httpaf with type 'a io = 'a Async_kernel.Deferred.t
                                          and type file_descr = Async_unix.Fd.t
