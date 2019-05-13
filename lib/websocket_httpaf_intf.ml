module type Websocket_httpaf = sig
  type +'a io
  type file_descr

  include module type of struct include Websocket end

  val upgrade_connection : ?headers:Httpaf.Headers.t ->
                           'handle Httpaf.Reqd.t ->
                           file_descr ->
                           (Websocket.Frame.t -> unit) ->
                           (Httpaf.Response.t * [ `write ] Httpaf.Body.t *
                            (Websocket.Frame.t option -> unit)) io
end
